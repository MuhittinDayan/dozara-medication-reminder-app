import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const modelName = "gemini-3.1-pro-preview";
const scanDailyLimit = 10;
const assistantDailyLimit = 20;

type GeminiPart = {
  text?: string;
  inlineData?: {
    mimeType: string;
    data: string;
  };
};

type GeminiContent = {
  role?: string;
  parts: GeminiPart[];
};

type RequestType = "scan" | "assistant";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function supabaseAdminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Supabase service credentials are missing.");
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

async function getAuthenticatedUserId(authorization: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const token = authorization.replace("Bearer ", "").trim();

  if (!supabaseUrl || !anonKey || !token) {
    return null;
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: {
      headers: { Authorization: authorization },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return null;
  }

  return data.user.id;
}

async function consumeQuota(userId: string, type: RequestType) {
  const limit = type === "scan" ? scanDailyLimit : assistantDailyLimit;
  const admin = supabaseAdminClient();
  const { data, error } = await admin.rpc("consume_ai_quota", {
    p_user_id: userId,
    p_feature: type,
    p_limit: limit,
  });

  if (error) {
    console.error("Quota RPC failed", error);
    return jsonResponse({ error: "Quota check failed." }, 500);
  }

  const quota = Array.isArray(data) ? data[0] : data;
  if (!quota?.allowed) {
    return jsonResponse(
      {
        code: "quota_exceeded",
        error: "Gunluk AI limiti doldu.",
        type,
        used: quota?.used ?? limit,
        limit: quota?.limit_value ?? limit,
        resetAt: quota?.reset_at,
      },
      429,
    );
  }

  return null;
}

function buildVisionPrompt(ocrText: string) {
  const normalizedText = ocrText.trim().length === 0
    ? "OCR bos veya okunamadi."
    : ocrText;

  return `
Bu bir ilac kutusu, recete ya da prospektus fotografi.
Elindeki iki kaynak var:
1. Goruntunun kendisi
2. OCR ile cikarilmis ham metin

Once OCR metnini kullan, sonra goruntuyle dogrula.
Kesin olmayan bilgileri tahmin etme. Emin degilsen "Belirsiz" yaz.
Ilac adini mumkun oldugunca marka veya urun adi olarak bul.
Kullanim metninden sabah, ogle, aksam, tok, ac, gunde kac kez, haftada bir, ayda bir gibi bilgileri yakala.

OCR METNI:
${normalizedText}

Yaniti yalnizca su formatta ver:
ISIM: [deger]
FORM: [Hap|Surup|Igne|Damla|Krem|Sprey|Diger|Belirsiz]
DOZ: [deger]
SIKLIK: [sayi veya Belirsiz]
YEMEK: [Tok|Ac|Farketmez|Belirsiz]
KULLANIM: [sabah/ogle/aksam/haftada bir/ayda bir gibi notlar]
`;
}

async function callGemini(contents: GeminiContent[]) {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return jsonResponse({ error: "GEMINI_API_KEY secret is missing." }, 500);
  }

  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents,
      generationConfig: {
        temperature: 0.2,
        topP: 0.8,
        topK: 32,
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    return jsonResponse(
      {
        error: "Gemini request failed.",
        status: response.status,
        details: payload,
      },
      502,
    );
  }

  const text = payload?.candidates
    ?.flatMap((candidate: { content?: { parts?: GeminiPart[] } }) =>
      candidate.content?.parts ?? []
    )
    ?.map((part: GeminiPart) => part.text ?? "")
    ?.join("\n")
    ?.trim();

  if (!text) {
    return jsonResponse({ error: "Gemini returned an empty response." }, 502);
  }

  return jsonResponse({ text });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Only POST is supported." }, 405);
  }

  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing Authorization header." }, 401);
  }

  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const userId = await getAuthenticatedUserId(authorization);
  if (!userId) {
    return jsonResponse(
      { error: "AI ozellikleri icin Supabase hesabi ile giris yapin." },
      401,
    );
  }

  if (body.type === "assistant") {
    const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
    if (!prompt) {
      return jsonResponse({ error: "Missing prompt." }, 400);
    }

    const quotaResponse = await consumeQuota(userId, "assistant");
    if (quotaResponse) {
      return quotaResponse;
    }

    return callGemini([
      {
        role: "user",
        parts: [{ text: prompt }],
      },
    ]);
  }

  if (body.type === "scan") {
    const imageBase64 = typeof body.imageBase64 === "string"
      ? body.imageBase64
      : "";
    const mimeType = typeof body.mimeType === "string"
      ? body.mimeType
      : "image/jpeg";
    const ocrText = typeof body.ocrText === "string" ? body.ocrText : "";

    if (!imageBase64) {
      return jsonResponse({ error: "Missing imageBase64." }, 400);
    }

    const quotaResponse = await consumeQuota(userId, "scan");
    if (quotaResponse) {
      return quotaResponse;
    }

    return callGemini([
      {
        role: "user",
        parts: [
          { text: buildVisionPrompt(ocrText) },
          {
            inlineData: {
              mimeType,
              data: imageBase64,
            },
          },
        ],
      },
    ]);
  }

  return jsonResponse({ error: "Unsupported request type." }, 400);
});

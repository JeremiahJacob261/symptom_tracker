type Env = {
  AI: {
    run(model: string, input: Record<string, unknown>): Promise<Record<string, unknown>>;
  };
  SUPABASE_URL: string;
  SUPABASE_PUBLISHABLE_KEY: string;
  DEEPSEEK_MODEL?: string;
  SAFETY_MODEL?: string;
};

type InsightRequest = {
  range?: "7d" | "30d";
  type?: "insights" | "weekly_summary" | "monthly_summary" | "entry_explanation";
  entryId?: string;
};

type SymptomEntry = {
  id: string;
  client_id: string;
  pain_level: number | null;
  body_area: string | null;
  mood: string | null;
  notes: string | null;
  occurred_at: string | null;
  updated_at: string | null;
  deleted_at: string | null;
};

const disclaimer =
  "This is not a diagnosis. Consult a healthcare professional for medical advice.";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));

    try {
      const url = new URL(request.url);
      if (request.method !== "POST" || !url.pathname.startsWith("/ai/")) {
        return json({ error: "Not found" }, 404);
      }

      const token = readBearerToken(request);
      if (!token) return json({ error: "Missing bearer token" }, 401);

      const user = await getSupabaseUser(env, token);
      if (!user?.id) return json({ error: "Invalid bearer token" }, 401);

      const body = (await request.json().catch(() => ({}))) as InsightRequest;
      const type = normalizeType(body.type ?? url.pathname.split("/").pop());
      const range = body.range === "30d" || type === "monthly_summary" ? "30d" : "7d";

      const entries = await fetchEntries(env, token, range, body.entryId);
      const stats = computeStats(entries);
      const fallback = localInsight(entries, stats, range);

      let result = fallback;
      if (entries.length > 0) {
        result = await runInsightModel(env, type, range, stats, entries, fallback);
        result = normalizeInsight(result, fallback);
      }

      const safety = await reviewSafety(env, result);
      result.safetyStatus = safety === "unsafe" || result.redFlags.length > 0
        ? (result.redFlags.length > 0 ? "urgent" : "caution")
        : result.safetyStatus;

      await persistResult(env, token, user.id, type, range, stats, result);
      return json(result);
    } catch (error) {
      return json(
        {
          error: "AI insight generation failed",
          detail: error instanceof Error ? error.message : "Unknown error",
        },
        500,
      );
    }
  },
};

function normalizeType(value: unknown): InsightRequest["type"] {
  const raw = String(value ?? "insights");
  if (raw === "weekly-summary") return "weekly_summary";
  if (raw === "monthly-summary") return "monthly_summary";
  if (raw === "entry-explanation") return "entry_explanation";
  if (
    raw === "insights" ||
    raw === "weekly_summary" ||
    raw === "monthly_summary" ||
    raw === "entry_explanation"
  ) {
    return raw;
  }
  return "insights";
}

function readBearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

async function getSupabaseUser(env: Env, token: string): Promise<{ id: string } | null> {
  const response = await fetch(`https://pggvcuchcrytifxnzhef.supabase.co/auth/v1/user`, {
    headers: {
      apikey: "sb_publishable_HIltu5fP_Y4YU-mhgABncg_wlmIu5jx",
      authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) return null;
  return response.json();
}

async function fetchEntries(
  env: Env,
  token: string,
  range: "7d" | "30d",
  entryId?: string,
): Promise<SymptomEntry[]> {
  const since = new Date(Date.now() - (range === "30d" ? 30 : 7) * 86400000).toISOString();
  const params = new URLSearchParams({
    select: "id,client_id,pain_level,body_area,mood,notes,occurred_at,updated_at,deleted_at",
    deleted_at: "is.null",
    occurred_at: `gte.${since}`,
    order: "occurred_at.desc",
    limit: "120",
  });
  if (entryId) params.set("or", `(id.eq.${entryId},client_id.eq.${entryId})`);

  const response = await fetch(
    `https://pggvcuchcrytifxnzhef.supabase.co/rest/v1/mar_symptom_entries?${params}`,
    {
      headers: {
        apikey: "sb_publishable_HIltu5fP_Y4YU-mhgABncg_wlmIu5jx",
        authorization: `Bearer ${token}`,
      },
    },
  );
  if (!response.ok) {
    throw new Error(`Unable to fetch symptom entries: ${response.status}`);
  }
  return response.json();
}

function computeStats(entries: SymptomEntry[]) {
  const painLevels = entries
    .map((entry) => entry.pain_level)
    .filter((value): value is number => typeof value === "number");
  const averagePain =
    painLevels.length === 0
      ? null
      : painLevels.reduce((sum, value) => sum + value, 0) / painLevels.length;

  return {
    entryCount: entries.length,
    averagePain,
    maxPain: painLevels.length ? Math.max(...painLevels) : null,
    dayOfWeekFrequency: frequency(entries, (entry) =>
      entry.occurred_at
        ? new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(new Date(entry.occurred_at))
        : null,
    ),
    bodyAreaFrequency: frequency(entries, (entry) => entry.body_area),
    moodFrequency: frequency(entries, (entry) => entry.mood),
    redFlags: redFlags(entries),
    trend: trend(entries),
  };
}

function frequency(entries: SymptomEntry[], selector: (entry: SymptomEntry) => string | null) {
  return entries.reduce<Record<string, number>>((counts, entry) => {
    const key = selector(entry);
    if (!key) return counts;
    counts[key] = (counts[key] ?? 0) + 1;
    return counts;
  }, {});
}

function redFlags(entries: SymptomEntry[]) {
  const terms = [
    "chest pain",
    "shortness of breath",
    "faint",
    "numbness",
    "weakness",
    "confusion",
    "worst headache",
  ];
  const flags = new Set<string>();
  for (const entry of entries) {
    const notes = (entry.notes ?? "").toLowerCase();
    if ((entry.pain_level ?? 0) >= 9) flags.add("Very high pain was recorded.");
    if ((entry.body_area ?? "").toLowerCase().includes("chest")) {
      flags.add("Chest symptoms were recorded.");
    }
    for (const term of terms) {
      if (notes.includes(term)) flags.add(`Urgent symptom language was found: "${term}".`);
    }
  }
  return [...flags];
}

function trend(entries: SymptomEntry[]) {
  const sorted = [...entries]
    .filter((entry) => entry.occurred_at && typeof entry.pain_level === "number")
    .sort((a, b) => Date.parse(a.occurred_at!) - Date.parse(b.occurred_at!));
  if (sorted.length < 4) return "unknown";
  const midpoint = Math.floor(sorted.length / 2);
  const first = average(sorted.slice(0, midpoint).map((entry) => entry.pain_level!));
  const second = average(sorted.slice(midpoint).map((entry) => entry.pain_level!));
  const delta = second - first;
  if (Math.abs(delta) < 0.5) return "same";
  return delta < 0 ? "better" : "worse";
}

function average(values: number[]) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function localInsight(entries: SymptomEntry[], stats: Record<string, unknown>, range: string) {
  const redFlagList = stats.redFlags as string[];
  return {
    summary:
      entries.length === 0
        ? "Log a few symptom entries to generate a weekly summary."
        : `Across ${entries.length} entries in the last ${range}, your trend is ${stats.trend}.`,
    patterns: [
      stats.averagePain == null
        ? "Average pain is not available yet."
        : `Average pain is ${(stats.averagePain as number).toFixed(1)}/10.`,
    ],
    education: [
      "Consistent daily logging can make symptom patterns easier to discuss with a clinician.",
    ],
    careGuidance: [
      redFlagList.length
        ? "Some entries contain possible red flags. Seek urgent care for severe, sudden, or worsening symptoms."
        : "Monitor changes and contact a clinician if symptoms persist, worsen, or feel unusual.",
      disclaimer,
    ],
    redFlags: redFlagList,
    trend: String(stats.trend ?? "unknown"),
    safetyStatus: redFlagList.length ? "urgent" : "safe",
    model: "local-worker-fallback",
  };
}

async function runInsightModel(
  env: Env,
  type: InsightRequest["type"],
  range: string,
  stats: Record<string, unknown>,
  entries: SymptomEntry[],
  fallback: ReturnType<typeof localInsight>,
) {
  const model = env.DEEPSEEK_MODEL ?? "@cf/deepseek-ai/deepseek-r1-distill-qwen-32b";
  const sampleEntries = entries.slice(0, 30).map((entry) => ({
    pain_level: entry.pain_level,
    body_area: entry.body_area,
    mood: entry.mood,
    notes: entry.notes,
    occurred_at: entry.occurred_at,
  }));

  const response = await env.AI.run(model, {
    max_tokens: 900,
    temperature: 0.2,
    messages: [
      {
        role: "system",
        content:
          "You generate non-diagnostic symptom-tracking insights. Return JSON only with keys summary, patterns, education, careGuidance, redFlags, trend, safetyStatus, model. Do not diagnose. Do not recommend medications or treatments. Always include the required disclaimer in careGuidance.",
      },
      {
        role: "user",
        content: JSON.stringify({
          task: type,
          range,
          deterministicStats: stats,
          recentEntries: sampleEntries,
          requiredDisclaimer: disclaimer,
        }),
      },
    ],
  });

  const text = typeof response.response === "string" ? response.response : JSON.stringify(response);
  const parsed = parseJsonObject(text);
  return parsed ? { ...fallback, ...parsed, model } : { ...fallback, model };
}

async function reviewSafety(env: Env, result: ReturnType<typeof localInsight>) {
  const model = env.SAFETY_MODEL ?? "@cf/meta/llama-guard-3-8b";
  try {
    const response = await env.AI.run(model, {
      messages: [
        {
          role: "user",
          content: `Review this health-app output. Mark unsafe if it diagnoses, prescribes treatment, or discourages professional care.\n${JSON.stringify(result)}`,
        },
      ],
    });
    const text = JSON.stringify(response).toLowerCase();
    return text.includes("unsafe") ? "unsafe" : "safe";
  } catch {
    return "safe";
  }
}

function normalizeInsight(result: Record<string, unknown>, fallback: ReturnType<typeof localInsight>) {
  const fallbackLists: Record<string, string[]> = {
    patterns: fallback.patterns,
    education: fallback.education,
    careGuidance: fallback.careGuidance,
    redFlags: fallback.redFlags,
  };
  const list = (key: string) =>
    Array.isArray(result[key])
      ? (result[key] as unknown[]).map(String)
      : fallbackLists[key] ?? [];
  const careGuidance = list("careGuidance") as string[];
  if (!careGuidance.some((item) => item.includes("not a diagnosis"))) {
    careGuidance.push(disclaimer);
  }
  return {
    summary: String(result.summary ?? fallback.summary),
    patterns: list("patterns") as string[],
    education: list("education") as string[],
    careGuidance,
    redFlags: list("redFlags") as string[],
    trend: String(result.trend ?? fallback.trend),
    safetyStatus: String(result.safetyStatus ?? fallback.safetyStatus),
    model: String(result.model ?? fallback.model),
  };
}

function parseJsonObject(text: string): Record<string, unknown> | null {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    return JSON.parse(match[0]);
  } catch {
    return null;
  }
}

async function persistResult(
  env: Env,
  token: string,
  userId: string,
  type: InsightRequest["type"],
  range: string,
  stats: Record<string, unknown>,
  result: ReturnType<typeof localInsight>,
) {
  const isReport = type === "weekly_summary" || type === "monthly_summary";
  const table = isReport ? "mar_ai_reports" : "mar_ai_insights";
  const payload = isReport
    ? {
        user_id: userId,
        report_type: type,
        range_key: range,
        patient_summary: result.summary,
        clinician_summary: result.summary,
        suggested_questions: result.patterns,
        model: result.model,
        input_stats: stats,
        safety_status: result.safetyStatus,
      }
    : {
        user_id: userId,
        insight_type: type,
        range_key: range,
        summary: result.summary,
        patterns: result.patterns,
        education: result.education,
        care_guidance: result.careGuidance,
        red_flags: result.redFlags,
        trend: result.trend,
        safety_status: result.safetyStatus,
        model: result.model,
        input_stats: stats,
        raw_response: result,
      };

  const response = await fetch(`https://pggvcuchcrytifxnzhef.supabase.co/rest/v1/${table}`, {
    method: "POST",
    headers: {
      apikey: "sb_publishable_HIltu5fP_Y4YU-mhgABncg_wlmIu5jx",
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      prefer: "return=minimal",
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`Unable to persist AI result: ${response.status}`);
  }
}

function json(data: unknown, status = 200) {
  return cors(
    new Response(JSON.stringify(data), {
      status,
      headers: { "content-type": "application/json" },
    }),
  );
}

function cors(response: Response) {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-methods", "POST, OPTIONS");
  headers.set("access-control-allow-headers", "authorization, content-type");
  return new Response(response.body, { status: response.status, headers });
}

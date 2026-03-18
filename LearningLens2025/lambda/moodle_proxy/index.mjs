const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};

function normalizeBaseUrl(url) {
  return (url ?? "").replace(/\/+$/, "");
}

function buildTargetUrl(event) {
  const moodleBaseUrl = normalizeBaseUrl(process.env.MOODLE_URL);
  if (!moodleBaseUrl) {
    throw new Error("MOODLE_URL is not configured for the Moodle proxy.");
  }

  const requestPath = (event.rawPath ?? "/").replace(/^\/+/, "");
  const targetPath = requestPath.length === 0 ? "" : `/${requestPath}`;
  const query = event.rawQueryString ? `?${event.rawQueryString}` : "";

  return `${moodleBaseUrl}${targetPath}${query}`;
}

function buildProxyHeaders(event) {
  const headers = {};
  const contentType = event.headers?.["content-type"] ?? event.headers?.["Content-Type"];
  const accept = event.headers?.accept ?? event.headers?.Accept;

  if (contentType) {
    headers["content-type"] = contentType;
  }
  if (accept) {
    headers["accept"] = accept;
  }

  return headers;
}

export const handler = async (event) => {
  if (event.requestContext?.http?.method === "OPTIONS") {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: "",
    };
  }

  try {
    const targetUrl = buildTargetUrl(event);
    const method = event.requestContext?.http?.method ?? "POST";
    const headers = buildProxyHeaders(event);

    const response = await fetch(targetUrl, {
      method,
      headers,
      body: ["GET", "HEAD"].includes(method)
          ? undefined
          : (event.isBase64Encoded
              ? Buffer.from(event.body ?? "", "base64")
              : event.body),
    });

    const body = await response.text();

    return {
      statusCode: response.status,
      headers: {
        ...corsHeaders,
        "Content-Type": response.headers.get("content-type") ?? "text/plain",
      },
      body,
    };
  } catch (error) {
    console.error("Moodle proxy failed:", error);

    return {
      statusCode: 502,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        error: "Moodle proxy request failed.",
        details: error.message,
      }),
    };
  }
};

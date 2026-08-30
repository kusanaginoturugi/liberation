export default {
  async fetch(request, env) {
    if (request.method !== "POST" || request.headers.get("Authorization") !== `Bearer ${env.PDF_TOKEN}`) {
      return new Response("Unauthorized", { status: 401 });
    }

    const { html } = await request.json();
    if (typeof html !== "string" || html.length === 0 || html.length > 50 * 1024 * 1024) {
      return new Response("Invalid document", { status: 400 });
    }

    const pdf = await env.BROWSER.quickAction("pdf", {
      html,
      pdfOptions: {
        format: "a4",
        landscape: false,
        printBackground: true,
        preferCSSPageSize: true
      }
    });

    if (!pdf.ok) {
      return new Response("PDF generation failed", { status: 502 });
    }

    return new Response(pdf.body, {
      headers: { "Content-Type": "application/pdf" }
    });
  }
};

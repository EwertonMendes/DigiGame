import { createServer } from "node:http";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const outputDirectory = resolve(root, "database", "source-data");
const allowedNames = new Set([
  "digimon-story-ds.json",
  "dawn-dusk.json",
  "lost-evolution.json",
  "super-xros-wars.json",
  "super-xros-wars-digixros.json",
]);

const page = `<!doctype html><html><body>
<label>File <input id="file"></label>
<label>JSON <textarea id="payload"></textarea></label>
<button id="save">Save</button><output id="result"></output>
<script>
save.onclick = async () => {
  const response = await fetch('/capture', {
    method: 'POST', headers: {'content-type': 'application/json'},
    body: JSON.stringify({file: file.value, rows: JSON.parse(payload.value)})
  });
  result.textContent = await response.text();
};
</script></body></html>`;

const server = createServer(async (request, response) => {
  if (request.method === "GET") {
    response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    response.end(page);
    return;
  }
  if (request.method !== "POST" || request.url !== "/capture") {
    response.writeHead(404).end("not found");
    return;
  }
  let body = "";
  for await (const chunk of request) body += chunk;
  const parsed = JSON.parse(body);
  if (!allowedNames.has(parsed.file) || !Array.isArray(parsed.rows)) {
    response.writeHead(400).end("invalid capture");
    return;
  }
  await mkdir(outputDirectory, { recursive: true });
  await writeFile(resolve(outputDirectory, parsed.file), JSON.stringify(parsed.rows, null, 2) + "\n", "utf8");
  response.writeHead(200).end(`saved ${parsed.rows.length} rows`);
});

server.listen(8765, "127.0.0.1", () => {
  process.stdout.write("Technique source capture listening on http://127.0.0.1:8765\n");
});

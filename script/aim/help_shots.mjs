// Retakes How AIM works' screenshots (#187) from a running local server,
// signed in as one person, into app/assets/images/aim/help/<name>.png
// (1440 x 900, the size the help page was laid out for). Run it through
// bin/aim-help-shots, which checks the setup first.
//
// It only looks. Every request that would change something is refused --
// form submit() is disabled inside the page, and any other non-GET is
// aborted -- except signing in, switching to Admin mode, and the Fiscal
// report preview, which renders and saves nothing. A second run, or a run
// after a crash, takes the same pictures again over the old ones.
import { mkdirSync } from "node:fs"

// bin/aim-help-shots finds Playwright and passes its folder.
const { chromium } = await import(process.env.AIM_PLAYWRIGHT || "playwright")

const base = process.argv[2] || "http://localhost:3002"
const employee = process.env.AIM_HELP_SHOTS_EMPLOYEE
const out = process.env.AIM_HELP_SHOTS_DIR || "app/assets/images/aim/help"
const ALLOWED = ["/login", "/aim/mode", "/aim/fiscal/export/preview"]

if (!employee) {
  console.error("Set AIM_HELP_SHOTS_EMPLOYEE to the employee id to sign in as (an AIM Admin).")
  process.exit(2)
}
mkdirSync(out, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } })
await page.addInitScript(() => {
  const refuse = function () { console.warn("help shots: a form submit was refused") }
  HTMLFormElement.prototype.submit = refuse
  HTMLFormElement.prototype.requestSubmit = refuse
  document.addEventListener("submit", (event) => {
    if (!(event.target.action || "").includes("/aim/fiscal/export/preview")) event.preventDefault()
  }, true)
})
await page.route("**/*", async (route) => {
  const request = route.request()
  if (request.method() === "GET" || ALLOWED.includes(new URL(request.url()).pathname)) return route.continue()
  await route.abort()
  console.warn(`help shots: blocked ${request.method()} ${new URL(request.url()).pathname}`)
})

const csrf = () => page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content || "")
const post = (path, body) => page.evaluate(async ([path, body]) => {
  await fetch(path, { method: "POST", credentials: "same-origin", body: new URLSearchParams(body) })
}, [path, body])
// Dismisses the startup warning dialog, if one is up.
const settle = async () => {
  await page.waitForTimeout(600)
  const ok = page.locator(".pb-modal-backdrop:not([hidden]) button", { hasText: /^(Continue|OK)$/ })
  if (await ok.count()) await ok.first().click()
  await page.waitForTimeout(300)
}
const visit = async (path) => { await page.goto(base + path, { waitUntil: "load" }); await settle() }
// Headless Chrome has no PDF viewer, so the review page's preview would be
// blank: draw the PDF's first page with pdf.js in its place, as a person sees it.
const drawPdfPreview = () => page.evaluate(async () => {
  const shell = document.querySelector(".aim-pdf-shell")
  const frame = shell?.querySelector("iframe")
  if (!frame) return
  if (!window.pdfjsLib) {
    await new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
    window.pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js"
  }
  const pdf = await window.pdfjsLib.getDocument({ url: frame.src.split("#")[0], withCredentials: true }).promise
  const first = await pdf.getPage(1)
  const room = shell.getBoundingClientRect()
  const plain = first.getViewport({ scale: 1 })
  const viewport = first.getViewport({ scale: Math.min(room.width / plain.width, room.height / plain.height) })
  const canvas = document.createElement("canvas")
  canvas.width = viewport.width
  canvas.height = viewport.height
  canvas.style.cssText = "display:block;margin:0 auto;box-shadow:0 1px 4px rgba(15,23,42,.3)"
  await first.render({ canvasContext: canvas.getContext("2d"), viewport }).promise
  frame.replaceWith(canvas)
})
const shoot = async (name) => {
  await page.screenshot({ path: `${out}/${name}.png` })
  console.log(`  ${name}.png`)
}

await visit("/")
await post("/login", { id: employee, authenticity_token: await csrf() })
await visit("/aim/dashboard")
await post("/aim/mode", { _method: "patch", mode: "admin", authenticity_token: await csrf() })

console.log(`Taking How AIM works screenshots from ${base}:`)
await visit("/aim/dashboard")
await shoot("dashboard")

await visit("/aim/find?where=ready_for_approval")
await shoot("find")

await visit("/aim/invoices?queue=needs_review")
await shoot("waiting")
const open = await page.locator(".aim-queue-table a.btn", { hasText: /^(Open|Resume Review|View)$/ }).first().getAttribute("href")
await visit(open)
await drawPdfPreview()
await shoot("review")
await visit(open)
if (await page.locator('[data-action="aim-pdf-editor#open"]').count()) {
  await page.click('[data-action="aim-pdf-editor#open"]')
  await page.waitForSelector(".aim-pdf-thumb canvas", { timeout: 20000 })
  await page.waitForTimeout(1200)
  await page.click('[data-action="aim-pdf-editor#text"]')
  const layer = await page.locator("[data-aim-pdf-editor-target=boxLayer]").boundingBox()
  await page.mouse.click(layer.x + layer.width * 0.55, layer.y + layer.height * 0.06)
  await page.keyboard.type("PAID - check 1001")
  await page.selectOption("[data-aim-pdf-editor-target=boxBg]", "yellow")
  await page.check("[data-aim-pdf-editor-target=boxBorder]")
  await page.waitForTimeout(400)
  await shoot("pdf_editor")
}

await visit("/aim/uploads/new")
await shoot("upload")

await visit("/aim/invoices?queue=exported&vendor=e")
await shoot("older")

await visit("/aim/admin/agency_groups")
const group = await page.locator(".aim-page a[href*='/aim/admin/agency_groups/']").first().getAttribute("href")
if (group) { await visit(group); await shoot("agency_group") }

await visit("/aim/fiscal/dashboard")
await shoot("fiscal_dashboard")

await visit("/aim/fiscal?status=exported")
const boxes = page.locator("input[name='record_ids[]']")
if (await boxes.count()) {
  for (let index = 0; index < Math.min(3, await boxes.count()); index++) await boxes.nth(index).check()
  await page.locator("button", { hasText: "Preview report" }).click()
  await page.waitForTimeout(2500)
  await shoot("fiscal_preview")
}

await browser.close()
console.log("Done. Look them over, then commit app/assets/images/aim/help/*.png.")

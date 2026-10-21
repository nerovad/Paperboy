// pdf.js, loaded on first use from cdnjs (allowed by the CSP), as the AIM
// PDF editor and OCR load it. Resolves to window.pdfjsLib.
const PDF_JS_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"
const PDF_WORKER_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js"

let loading = null

export function loadPdfJs() {
  if (window.pdfjsLib) {
    window.pdfjsLib.GlobalWorkerOptions.workerSrc ||= PDF_WORKER_URL
    return Promise.resolve(window.pdfjsLib)
  }
  loading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = PDF_JS_URL
    script.onload = () => {
      window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDF_WORKER_URL
      resolve(window.pdfjsLib)
    }
    script.onerror = reject
    document.head.appendChild(script)
  })
  return loading
}

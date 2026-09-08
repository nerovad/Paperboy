import os
import time
import json
import fitz
import ollama
from dotenv import load_dotenv
from PIL import Image

# The two models to compare. Configured, not hardcoded -- these change with
# every move to new hardware.

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def env_file_candidates():
    explicit_env_file = os.getenv("AIM_ENV_FILE")
    candidates = []
    if explicit_env_file:
        candidates.append(explicit_env_file)

    candidates.append(os.path.join(SCRIPT_DIR, ".env"))

    seen = set()
    for candidate in candidates:
        normalized = os.path.abspath(candidate)
        if normalized in seen:
            continue
        seen.add(normalized)
        yield normalized

for env_file in env_file_candidates():
    if os.path.exists(env_file):
        load_dotenv(env_file)
        break

from pipeline_common import env

MODEL_A = env("AIM_BENCHMARK_MODEL_A")
MODEL_B = env("AIM_BENCHMARK_MODEL_B")
TEST_DIR = env("AIM_BENCHMARK_DIR")
TEMP_IMAGE = "temp_benchmark.jpg"

PROMPT = (
    "Analyze this document image. "
    "Extract the exact literal vendor name as 'extracted_vendor_name', invoice_date, invoice_number, invoice_total, and if present order_number, "
    "subtotal, sales_tax, and customer_number. "
    "CRITICAL RULES: "
    "1. For 'invoice_number', use the vendor's invoice number. Keep any leading zeros. "
    "2. If you see multiple values that map to invoice_total, and one is $0.00, IGNORE the $0.00 value and extract the non-zero amount. "
    "Return strictly as JSON."
)

SCHEMA = {
    "type": "object",
    "properties": {
        "extracted_vendor_name": {"type": "string"},
        "invoice_date": {"type": "string"},
        "invoice_number": {"type": "string"},
        "invoice_total": {"type": "string"},
        "subtotal": {"type": "string"},
        "sales_tax": {"type": "string"}
    }
}

def pdf_page_to_image(pdf_path, page_num, output_path):
    doc = fitz.open(pdf_path)
    page = doc[page_num]
    matrix = fitz.Matrix(1.5, 1.5)
    pix = page.get_pixmap(matrix=matrix)
    pix.save(output_path)
    doc.close()

def run_model(model_name, image_path):
    start_time = time.time()
    try:
        response = ollama.chat(
            model=model_name,
            messages=[{'role': 'user', 'content': PROMPT, 'images': [image_path]}],
            format=SCHEMA,
            options={'temperature': 0, 'num_ctx': 8192}
        )
        duration = time.time() - start_time
        data = json.loads(response['message']['content'])
        return data, duration
    except Exception as e:
        return {"error": str(e)}, time.time() - start_time

def main():
    print(f"Starting A/B Benchmark: {MODEL_A} vs {MODEL_B}")
    print(f"Scanning directory: {TEST_DIR}\n")

    # Gather all PDF files first
    pdf_files = []
    for root, dirs, files in os.walk(TEST_DIR):
        # Prevent it from diving into _ACTION_NEEDED, _PROCESSED, etc.
        dirs[:] = [d for d in dirs if not (d.startswith('_') or d.startswith('.'))]

        for filename in files:
            if filename.lower().endswith(".pdf"):
                pdf_files.append((filename, os.path.join(root, filename)))

    if not pdf_files:
        print("No PDFs found!")
        return

    # Initialize results dictionary
    results_dict = {filename: {"File": filename} for filename, _ in pdf_files}

    # Run Model A on all files
    print(f"\n--- Phase 1: Processing all files with {MODEL_A} ---")
    for filename, pdf_path in pdf_files:
        print(f"  - Testing: {filename}...")
        pdf_page_to_image(pdf_path, 0, TEMP_IMAGE)
        data_a, time_a = run_model(MODEL_A, TEMP_IMAGE)
        results_dict[filename][f"{MODEL_A} Time (s)"] = round(time_a, 1)
        results_dict[filename][f"{MODEL_A} Vendor"] = data_a.get('extracted_vendor_name')
        results_dict[filename][f"{MODEL_A} Total"] = data_a.get('invoice_total')
        print(f"    [Time] {time_a:.1f}s")

    # Run Model B on all files
    print(f"\n--- Phase 2: Processing all files with {MODEL_B} ---")
    for filename, pdf_path in pdf_files:
        print(f"  - Testing: {filename}...")
        pdf_page_to_image(pdf_path, 0, TEMP_IMAGE)
        data_b, time_b = run_model(MODEL_B, TEMP_IMAGE)
        results_dict[filename][f"{MODEL_B} Time (s)"] = round(time_b, 1)
        results_dict[filename][f"{MODEL_B} Vendor"] = data_b.get('extracted_vendor_name')
        results_dict[filename][f"{MODEL_B} Total"] = data_b.get('invoice_total')
        print(f"    [Time] {time_b:.1f}s")

    results = list(results_dict.values())

    if os.path.exists(TEMP_IMAGE):
        os.remove(TEMP_IMAGE)

    import csv
    with open("benchmark_results.csv", "w", newline="", encoding="utf-8") as f:
        if results:
            writer = csv.DictWriter(f, fieldnames=results[0].keys())
            writer.writeheader()
            writer.writerows(results)

    print("Benchmark complete! Results saved to benchmark_results.csv")

if __name__ == "__main__":
    main()

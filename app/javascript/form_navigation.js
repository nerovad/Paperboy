window.formNavigationLoaded = true;
console.log("form_navigation.js is REALLY loaded");

document.addEventListener("turbo:load", () => {
  console.log("form_navigation.js loaded on turbo:load");

  // ✅ Page Navigation
  const pages = document.querySelectorAll(".form-page");
  const nextBtn = document.getElementById("nextBtn");
  const prevBtn = document.getElementById("prevBtn");
  const submitBtn = document.querySelector("input[type='submit']");

  if (pages.length === 0) return;

  let current = 0;
  showPage(current);

  nextBtn?.addEventListener("click", () => {
    console.log("Next clicked");
    if (current < pages.length - 1) {
      current++;
      showPage(current);
    }
  });

  prevBtn?.addEventListener("click", () => {
    console.log("Previous clicked");
    if (current > 0) {
      current--;
      showPage(current);
    }
  });

  function showPage(index) {
    pages.forEach((page, i) => {
      page.style.display = i === index ? "" : "none";
    });

    if (submitBtn) {
      submitBtn.style.display = index === pages.length - 1 ? "inline-block" : "none";
    }

    if (nextBtn) {
      nextBtn.style.display = index === pages.length - 1 ? "none" : "inline-block";
    }

    if (prevBtn) {
      prevBtn.style.display = index === 0 ? "none" : "inline-block";
    }

    const dots = document.querySelectorAll(".progress-dots .dot");
    dots.forEach((dot, i) => {
      dot.classList.toggle("active", i === index);
    });
  }

  // ✅ Add/Remove Vehicle
  const wrapper = document.getElementById("vehicle-wrapper");
  const addBtn = document.getElementById("add-vehicle");
  const template = document.getElementById("vehicle-template");
  let vehicleIndex = 1;

  addBtn?.addEventListener("click", () => {
    const html = template.innerHTML.replace(/NEW_RECORD/g, vehicleIndex);
    wrapper.insertAdjacentHTML("beforeend", html);
    vehicleIndex++;
  });

  wrapper?.addEventListener("click", (e) => {
    if (e.target.classList.contains("remove-vehicle")) {
      const vehicleSet = e.target.closest(".vehicle-fields");
      vehicleSet.remove();
    }
  });

  wrapper?.addEventListener("change", (e) => {
    if (e.target.classList.contains("parking-lot-select")) {
      const group = e.target.closest(".vehicle-fields");
      const otherInput = group.querySelector(".other-lot-field");

      if (e.target.value === "Other") {
        otherInput.style.display = "block";
      } else {
        otherInput.style.display = "none";
        otherInput.value = "";
      }
    }
  });
});

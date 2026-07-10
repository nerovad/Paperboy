import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!window.jQuery || !window.jQuery.fn.DataTable || this.element.dataset.datatableInitialized === "true") return

    const table = window.jQuery(this.element).DataTable({
      dom: "Bfrtip",
      orderCellsTop: true,
      pageLength: 25,
      responsive: true,
      buttons: [
        { extend: "copyHtml5", title: this.exportTitle },
        { extend: "csvHtml5", title: this.exportTitle },
        { extend: "print", title: this.exportTitle }
      ]
    })

    table.columns().every(function () {
      const column = this
      const input = column.table().node().querySelectorAll("thead tr.column-filters input")[column.index()]
      if (!input) return

      input.addEventListener("keyup", () => {
        if (column.search() !== input.value) column.search(input.value).draw()
      })
      input.addEventListener("change", () => {
        if (column.search() !== input.value) column.search(input.value).draw()
      })
      input.addEventListener("click", event => event.stopPropagation())
    })

    this.element.dataset.datatableInitialized = "true"
  }

  get exportTitle() {
    return this.element.dataset.exportTitle || "DataRunner output"
  }
}

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"];

  connect() {
    this.clear(this.divisionTarget);
    this.clear(this.departmentTarget);
    this.clear(this.unitTarget);
  }

  async loadDivisions() {
    const agency = this.agencyTarget.value;
    this.clear(this.divisionTarget);
    this.clear(this.departmentTarget);
    this.clear(this.unitTarget);

    const res = await fetch(`/api/divisions?agency=${agency}`);
    const data = await res.json();
    this.populate(this.divisionTarget, data);
  }

  async loadDepartments() {
    const agency = this.agencyTarget.value;
    const division = this.divisionTarget.value;
    this.clear(this.departmentTarget);
    this.clear(this.unitTarget);

    const res = await fetch(`/api/departments?agency=${agency}&division=${division}`);
    const data = await res.json();
    this.populate(this.departmentTarget, data);
  }

  async loadUnits() {
    const agency = this.agencyTarget.value;
    const division = this.divisionTarget.value;
    const department = this.departmentTarget.value;
    this.clear(this.unitTarget);

    const res = await fetch(`/api/units?agency=${agency}&division=${division}&department=${department}`);
    const data = await res.json();
    this.populate(this.unitTarget, data);
  }

  populate(select, data) {
    data.forEach(({ label, value }) => {
      select.add(new Option(label, value));
    });
  }

  clear(select) {
    select.innerHTML = "";
    select.add(new Option("Select one", ""));
  }
}

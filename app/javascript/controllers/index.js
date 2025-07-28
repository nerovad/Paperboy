import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

import FormController from "./form_controller"
import FormNavigationController from "./form_navigation_controller"

application.register("form-navigation", FormNavigationController)
application.register("form", FormController)

eagerLoadControllersFrom("controllers", application)

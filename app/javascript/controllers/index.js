import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

import FormNavigationController from "./form_navigation_controller"

application.register("form-navigation", FormNavigationController)

eagerLoadControllersFrom("controllers", application)

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

import FormNavigationController from "./form_navigation_controller"
import LoginModalController from "./login_modal_controller"
import ProfileDropdownController from "./profile_dropdown_controller"
import ProbationTransferRequestController from "./probation_transfer_request_controller"

application.register("probation-transfer-request", ProbationTransferRequestController)
application.register("form-navigation", FormNavigationController)
application.register("login-modal", LoginModalController)
application.register("profile-dropdown", ProfileDropdownController)

eagerLoadControllersFrom("controllers", application)

import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

import FormNavigationController from "./form_navigation_controller"
import LoginModalController from "./login_modal_controller"
import ProfileDropdownController from "./profile_dropdown_controller"
import ProbationTransferRequestController from "./probation_transfer_request_controller"
import SlideshowController from "./slideshow_controller"
import ConfirmController from "./confirm_controller"
import DenyModalController from "./deny_modal_controller"
import PhoneController from "./phone_controller"
import BillingModalController from "./billing_modal_controller"
import ApproveModalController from "./approve_modal_controller"
import ChoicesController from "./choices_controller"
import ConditionalFieldController from "./conditional_field_controller.js"

application.register("slideshow", SlideshowController)
application.register("probation-transfer-request", ProbationTransferRequestController)
application.register("form-navigation", FormNavigationController)
application.register("login-modal", LoginModalController)
application.register("profile-dropdown", ProfileDropdownController)
application.register("confirm", ConfirmController)
application.register("deny-modal", DenyModalController)
application.register("phone", PhoneController)
application.register("billing-modal", BillingModalController)
application.register("approve-modal", ApproveModalController)
application.register("choices", ChoicesController)
application.register("conditional-field-controller", ConditionalFieldController)

eagerLoadControllersFrom("controllers", application)

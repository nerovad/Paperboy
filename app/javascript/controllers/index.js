// app/javascript/controllers/index.js
import { application } from "controllers/application"

import FormNavigationController from "controllers/form_navigation_controller"
import LoginModalController from "controllers/login_modal_controller"
import ProfileDropdownController from "controllers/profile_dropdown_controller"
import ProbationTransferRequestController from "controllers/probation_transfer_request_controller"
import SlideshowController from "controllers/slideshow_controller"
import ConfirmController from "controllers/confirm_controller"
import DenyModalController from "controllers/deny_modal_controller"
import PhoneController from "controllers/phone_controller"
import BillingModalController from "controllers/billing_modal_controller"
import ApproveModalController from "controllers/approve_modal_controller"
import ChoicesController from "controllers/choices_controller"
import ConditionalFieldController from "controllers/conditional_field_controller"
import GsabssSelectsController from "controllers/gsabss_selects_controller"
import SidebarSearchController from "controllers/sidebar_search_controller"
import FormBuilderController from "controllers/form_builder_controller"
import ReportsController from "controllers/reports_controller"
import ScheduledReportController from "controllers/scheduled_report_form_controller"
import SidebarController from "controllers/sidebar_controller"
import ConfirmModalController from "controllers/confirm_modal_controller"

// Register controllers with their data-controller names
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
application.register("conditional-field", ConditionalFieldController)
application.register("gsabss-selects", GsabssSelectsController)
application.register("sidebar-search", SidebarSearchController)
application.register("form-builder", FormBuilderController)
application.register("reports", ReportsController)
application.register("scheduled-report-form", ScheduledReportController)
application.register("sidebar", SidebarController)
application.register("confirm-modal", ConfirmModalController)

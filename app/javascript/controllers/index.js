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
import BillingToolsController from "controllers/billing_tools_controller"
import BillingTypesController from "controllers/billing_types_controller"
import BillingEmailSelectionController from "controllers/billing_email_selection_controller"
import BillingReportPreviewController from "controllers/billing_report_preview_controller"
import BillingAuditSectionsController from "controllers/billing_audit_sections_controller"
import DataRefreshGroupsController from "controllers/data_refresh_groups_controller"
import CoaAccountFieldsController from "controllers/coa_account_fields_controller"
import ApproveModalController from "controllers/approve_modal_controller"
import ReassignModalController from "controllers/reassign_modal_controller"
import ChoicesController from "controllers/choices_controller"
import ConditionalFieldController from "controllers/conditional_field_controller"
import ConditionalFieldsController from "controllers/conditional_fields_controller"
import GsabssSelectsController from "controllers/gsabss_selects_controller"
import BikeLockerSelectsController from "controllers/bike_locker_selects_controller"
import SidebarSearchController from "controllers/sidebar_search_controller"
import WhoAmIController from "controllers/who_am_i_controller"
import CommandPaletteController from "controllers/command_palette_controller"
import TipsController from "controllers/tips_controller"
import SearchCommandController from "controllers/search_command_controller"
import FormBuilderController from "controllers/form_builder_controller"
import ReportsController from "controllers/reports_controller"
import ScheduledReportController from "controllers/scheduled_report_form_controller"
import SidebarController from "controllers/sidebar_controller"
import ConfirmModalController from "controllers/confirm_modal_controller"
import AutoSubmitController from "controllers/auto_submit_controller"
import FilePreviewController from "controllers/file_preview_controller"
import TaskSelectionController from "controllers/task_selection_controller"
import StatusFiltersController from "controllers/status_filters_controller"
import ColumnCustomizerController from "controllers/column_customizer_controller"
import RecordsEditController from "controllers/records_edit_controller"
import RecordsConditionController from "controllers/records_condition_controller"
import RecordsEmailController from "controllers/records_email_controller"
import RecordsExportController from "controllers/records_export_controller"
import TagChipsController from "controllers/tag_chips_controller"
import UrgencyMapController from "controllers/urgency_map_controller"
import NhtsaVehicleController from "controllers/nhtsa_vehicle_controller"
import VehicleListController from "controllers/vehicle_list_controller"
import RepeatableSectionController from "controllers/repeatable_section_controller"
import SearchableSelectController from "controllers/searchable_select_controller"
import RecordsHighlightsController from "controllers/records_highlights_controller"
import LookupFilterController from "controllers/lookup_filter_controller"
import SecondaryLocationController from "controllers/secondary_location_controller"
import GroupSelectController from "controllers/group_select_controller"
import SavedSearchController from "controllers/saved_search_controller"
import TabsController from "controllers/tabs_controller"
import OrgPermissionsController from "controllers/org_permissions_controller"
import ToastController from "controllers/toast_controller"
import DeleteFormController from "controllers/delete_form_controller"
import FormDuplicateController from "controllers/form_duplicate_controller"
import SelectAllController from "controllers/select_all_controller"
import DependentSelectController from "controllers/dependent_select_controller"
import ClickableRowController from "controllers/clickable_row_controller"
import InformationFieldController from "controllers/information_field_controller"
import CardToggleController from "controllers/card_toggle_controller"
import AuthorizationSelectController from "controllers/authorization_select_controller"
import HistoryModalController from "controllers/history_modal_controller"
import CommentThreadController from "controllers/comment_thread_controller"
import ChangeStatusModalController from "controllers/change_status_modal_controller"
import BackLinkController from "controllers/back_link_controller"
import ContractorSelectsController from "controllers/contractor_selects_controller"
import DashboardsController from "controllers/dashboards_controller"
import AccountMenuController from "controllers/account_menu_controller"
import DslDragController from "controllers/dsl_drag_controller"
import DslGroupController from "controllers/dsl_group_controller"
import ProgressTrackerController from "controllers/progress_tracker_controller"
import OutputTableController from "controllers/output_table_controller"
import SourceEditorController from "controllers/source_editor_controller"
import SopModalController from "controllers/sop_modal_controller"
import DatabaseDslController from "controllers/database_dsl_controller"
import AppSwitcherController from "controllers/app_switcher_controller"
import DamSearchController from "controllers/dam_search_controller"
import DamSelectionController from "controllers/dam_selection_controller"
import PublishTargetController from "controllers/publish_target_controller"
import PublishFormController from "controllers/publish_form_controller"
import OrgCascadeController from "controllers/org_cascade_controller"
import CoaBillingLookupController from "controllers/coa_billing_lookup_controller"
import CoaBillingStringController from "controllers/coa_billing_string_controller"
import CoaAccountHierarchyController from "controllers/coa_account_hierarchy_controller"
import CoaCustomerLookupController from "controllers/coa_customer_lookup_controller"
import CustomerLookupRowsController from "controllers/customer_lookup_rows_controller"
import AimOcrController from "controllers/aim_ocr_controller"
import AimMoveModalController from "controllers/aim_move_modal_controller"
import AimDropzoneController from "controllers/aim_dropzone_controller"
import AimPersonSearchController from "controllers/aim_person_search_controller"
import AimCountsController from "controllers/aim_counts_controller"
import AimQueueFilterController from "controllers/aim_queue_filter_controller"
import AimOwnerChoiceController from "controllers/aim_owner_choice_controller"
import AimPresenceController from "controllers/aim_presence_controller"
import AimReasonController from "controllers/aim_reason_controller"
import AimSidebarController from "controllers/aim_sidebar_controller"
import AimActionsMenuController from "controllers/aim_actions_menu_controller"
import AimGroupedSearchController from "controllers/aim_grouped_search_controller"
import AimCodingChoiceController from "controllers/aim_coding_choice_controller"
import HsaAdoptionCardsController from "controllers/hsa_adoption_cards_controller"
import DateRangeController from "controllers/date_range_controller"
import PdfPreviewController from "controllers/pdf_preview_controller"
import PrinterSelectionController from "controllers/printer_selection_controller"
import P2mPostTestingArchiveController from "controllers/p2m_post_testing_archive_controller"
import NavigationProgressController from "controllers/navigation_progress_controller"
import P2mQualityControlController from "controllers/p2m_quality_control_controller"
import StartupWarningController from "controllers/startup_warning_controller"
import PfaGridController from "controllers/pfa_grid_controller"

// Register controllers with their data-controller names
application.register("slideshow", SlideshowController)
application.register("date-range", DateRangeController)
application.register("pdf-preview", PdfPreviewController)
application.register("probation-transfer-request", ProbationTransferRequestController)
application.register("form-navigation", FormNavigationController)
application.register("login-modal", LoginModalController)
application.register("profile-dropdown", ProfileDropdownController)
application.register("confirm", ConfirmController)
application.register("deny-modal", DenyModalController)
application.register("phone", PhoneController)
application.register("billing-modal", BillingModalController)
application.register("billing-tools", BillingToolsController)
application.register("billing-types", BillingTypesController)
application.register("billing-email-selection", BillingEmailSelectionController)
application.register("billing-report-preview", BillingReportPreviewController)
application.register("data-refresh-groups", DataRefreshGroupsController)
application.register("printer-selection", PrinterSelectionController)
application.register("p2m-post-testing-archive", P2mPostTestingArchiveController)
application.register("navigation-progress", NavigationProgressController)
application.register("p2m-quality-control", P2mQualityControlController)
application.register("startup-warning", StartupWarningController)
application.register("pfa-grid", PfaGridController)
application.register("coa-account-fields", CoaAccountFieldsController)
application.register("approve-modal", ApproveModalController)
application.register("reassign-modal", ReassignModalController)
application.register("choices", ChoicesController)
application.register("conditional-field", ConditionalFieldController)
application.register("conditional-fields", ConditionalFieldsController)
application.register("gsabss-selects", GsabssSelectsController)
application.register("bike-locker-selects", BikeLockerSelectsController)
application.register("sidebar-search", SidebarSearchController)
application.register("who-am-i", WhoAmIController)
application.register("command-palette", CommandPaletteController)
application.register("tips", TipsController)
application.register("search-command", SearchCommandController)
application.register("coa-customer-lookup", CoaCustomerLookupController)
application.register("customer-lookup-rows", CustomerLookupRowsController)
application.register("coa-billing-string", CoaBillingStringController)
application.register("coa-account-hierarchy", CoaAccountHierarchyController)
application.register("form-builder", FormBuilderController)
application.register("reports", ReportsController)
application.register("scheduled-report-form", ScheduledReportController)
application.register("sidebar", SidebarController)
application.register("confirm-modal", ConfirmModalController)
application.register("auto-submit", AutoSubmitController)
application.register("file-preview", FilePreviewController)
application.register("task-selection", TaskSelectionController)
application.register("status-filters", StatusFiltersController)
application.register("column-customizer", ColumnCustomizerController)
application.register("records-edit", RecordsEditController)
application.register("records-condition", RecordsConditionController)
application.register("records-email", RecordsEmailController)
application.register("records-export", RecordsExportController)
application.register("tag-chips", TagChipsController)
application.register("urgency-map", UrgencyMapController)
application.register("nhtsa-vehicle", NhtsaVehicleController)
application.register("vehicle-list", VehicleListController)
application.register("repeatable-section", RepeatableSectionController)
application.register("searchable-select", SearchableSelectController)
application.register("records-highlights", RecordsHighlightsController)
application.register("lookup-filter", LookupFilterController)
application.register("secondary-location", SecondaryLocationController)
application.register("group-select", GroupSelectController)
application.register("saved-search", SavedSearchController)
application.register("tabs", TabsController)
application.register("org-permissions", OrgPermissionsController)
application.register("toast", ToastController)
application.register("delete-form", DeleteFormController)
application.register("form-duplicate", FormDuplicateController)
application.register("select-all", SelectAllController)
application.register("dependent-select", DependentSelectController)
application.register("clickable-row", ClickableRowController)
application.register("billing-audit-sections", BillingAuditSectionsController)
application.register("information-field", InformationFieldController)
application.register("card-toggle", CardToggleController)
application.register("authorization-select", AuthorizationSelectController)
application.register("history-modal", HistoryModalController)
application.register("comment-thread", CommentThreadController)
application.register("change-status-modal", ChangeStatusModalController)
application.register("back-link", BackLinkController)
application.register("contractor-selects", ContractorSelectsController)
application.register("dashboards", DashboardsController)
application.register("account-menu", AccountMenuController)
application.register("dsl-drag", DslDragController)
application.register("dsl-group", DslGroupController)
application.register("progress-tracker", ProgressTrackerController)
application.register("output-table", OutputTableController)
application.register("source-editor", SourceEditorController)
application.register("sop-modal", SopModalController)
application.register("database-dsl", DatabaseDslController)
application.register("app-switcher", AppSwitcherController)
application.register("dam-search", DamSearchController)
application.register("dam-selection", DamSelectionController)
application.register("publish-target", PublishTargetController)
application.register("publish-form", PublishFormController)
application.register("org-cascade", OrgCascadeController)
application.register("coa-billing-lookup", CoaBillingLookupController)
application.register("aim-ocr", AimOcrController)
application.register("aim-move-modal", AimMoveModalController)
application.register("aim-dropzone", AimDropzoneController)
application.register("aim-person-search", AimPersonSearchController)
application.register("aim-counts", AimCountsController)
application.register("aim-queue-filter", AimQueueFilterController)
application.register("aim-owner-choice", AimOwnerChoiceController)
application.register("aim-presence", AimPresenceController)
application.register("aim-reason", AimReasonController)
application.register("aim-sidebar", AimSidebarController)
application.register("aim-actions-menu", AimActionsMenuController)
application.register("aim-grouped-search", AimGroupedSearchController)
application.register("aim-coding-choice", AimCodingChoiceController)
application.register("hsa-adoption-cards", HsaAdoptionCardsController)

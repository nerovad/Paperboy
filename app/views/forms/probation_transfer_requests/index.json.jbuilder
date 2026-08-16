# frozen_string_literal: true

json.array! @probation_transfer_requests,
            partial: 'forms/probation_transfer_requests/probation_transfer_request',
            as: :probation_transfer_request

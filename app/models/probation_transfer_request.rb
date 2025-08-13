class ProbationTransferRequest < ApplicationRecord

  STATUS_MAP = {
    0 => "submitted",
    1 => "manager_approved",
    2 => "denied",
    3 => "sent_to_security"
  }

  def status_label
    STATUS_MAP[status]
  end

  def submitted?
    status == 0
  end
  def manager_approved?
  status == 1
end

def denied?
  status == 2
end

def sent_to_security?
  status == 3
end
end

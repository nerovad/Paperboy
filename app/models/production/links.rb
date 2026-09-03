# frozen_string_literal: true

module Production
  # The Production app's sidebar: a bookmark list of the systems the print shop
  # works in every day. Nothing here is a Paperboy screen, so every entry opens
  # in a new tab.
  #
  # It lived in the sidebar partial until the command palette needed it too —
  # "asana", "timecard" or "vcfms" typed anywhere should land on the thing
  # itself, not on the page that lists it.
  #
  # `group` selects the collapsible sidebar section; `title` is the link's
  # tooltip, and doubles as the words the palette can match on.
  module Links
    GROUP_LABELS = {
      paperboy: 'Paperboy Environments',
      production: 'Production Systems',
      projects: 'Projects & Support',
      finance: 'Finance & Operations',
      people: 'Employee & Facilities'
    }.freeze

    ALL = [
      { label: 'Production',  url: 'https://gsa-forms',       group: :paperboy, title: 'Paperboy Production Server' },
      { label: 'Staging',     url: 'https://stage-gsa-forms', group: :paperboy, title: 'Paperboy Staging Server' },
      { label: 'Development', url: 'https://dev-gsa-forms',   group: :paperboy, title: 'Paperboy Development Server' },
      { label: 'ACO', url: 'http://acweb/index.php/vcfms', group: :finance, title: "Audit-Controller's Office" },
      { label: 'Asana', url: 'https://app.asana.com/', group: :projects, title: 'Powerpuff Girls: Paperboy issue tracking' },
      { label: 'CalSAWS', url: 'https://id.calsaws.net/#/login', group: :finance, title: 'CalSAWS sign in' },
      { label: 'Creative Service Lookbook',
        url: 'https://indd.adobe.com/view/ea6cbcee-f331-4b4e-9ea7-c92a33f81239', group: :production,
        title: 'Creative Services Lookbook highlighting capabilities' },
      { label: 'DocuShare', url: 'http://docushare', group: :production, title: 'Document Management Catalog Items' },
      { label: 'Gitea', url: 'http://gsa-gitea:3000/user/login', group: :projects, title: 'Business Support Services source code repositories' },
      { label: 'GSA Service Desk', url: 'https://gsa-itportal', group: :projects, title: 'GSA Service Desk and Employee Portal' },
      { label: 'Impress Automate', url: 'http://gsa-oms:690/local/#/login', group: :production, title: 'Print 2 Mail' },
      { label: 'Legacy e-Forms', url: 'http://docushare:99/jsp/login.jsp', group: :production, title: 'Liquid Office' },
      { label: 'Legacy PSI:Fusion', url: 'http://gsa-scan01:8080', group: :finance, title: 'AIM Automated Invoice Management' },
      { label: 'MainStar', url: 'https://venturagsa.maintstar.co/portal/#/workRequestAdd', group: :people, title: 'Maintenance work orders - Facilities' },
      { label: 'MyVCWeb', url: 'http://MyVCWeb', group: :people, title: 'Ventura Intranet - County resources - County' },
      { label: 'Purchase Order Status',
        url: 'https://app.powerbigov.us/view?r=eyJrIjoiNTlkYmY1YzItNjdkNy00NDYzLWIzOGQtZDU4ZDUwY2EyMDhlIiwidCI6ImJjZTBlYzA0LWQxZjEtNGY1YS1hMDUwLWE0YjVlOTE4MTY4MyJ9',
        group: :finance, title: 'Status of GSA Purchase Orders' },
      { label: 'TargetSolutions', url: 'https://app.targetsolutions.com/', group: :people, title: 'Safety and compliance - Risk' },
      { label: 'USPS Gateway', url: 'https://gateway.usps.com/eAdmin/view/signin', group: :production, title: 'USPS Business Customer Gateway' },
      { label: 'VCFMS', url: 'https://vcfms.cgiadvantage.com/PRDFIN1X1/Advantage4', group: :finance, title: 'Ventura County Financial Management System' },
      { label: 'VCHRP', url: 'https://vchrp.co.ventura.ca.us/', group: :people, title: 'HR and Payroll - Counthy - HR' },
      { label: 'VCLearning', url: 'https://sts.ventura.org/adfs/ls/idpinitiatedsignon.aspx', group: :people, title: 'Training and Learning - County HR' },
      { label: 'VCPrint', url: 'https://vcprint/public/login', group: :production, title: 'VCPrint - Print on Demand' },
      { label: 'VCWorkplace', url: 'https://gsa-fm-01.ent.co.ventura.ca.us/FMInteract/Default.aspx', group: :people, title: 'Facilities Management - GSA FM' }
    ].freeze

    def self.grouped
      links_by_group = ALL.group_by { |link| link[:group] }
      GROUP_LABELS.keys.to_h { |group| [group, links_by_group.fetch(group)] }
    end
  end
end

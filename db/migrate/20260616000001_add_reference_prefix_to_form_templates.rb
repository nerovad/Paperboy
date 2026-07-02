class AddReferencePrefixToFormTemplates < ActiveRecord::Migration[8.0]
  # Short, human-readable code that fronts a submission's reference number
  # (the "LOA" in "LOA-1042"). Combined with the record id it gives every
  # submission a reference users can search on in the inbox. Admin-editable per
  # template; auto-seeded on create from the class name's initials.
  def up
    add_column :form_templates, :reference_prefix, :string

    # Backfill existing templates with a unique prefix — a preferred seed value
    # when one is defined, otherwise the derived initials, deduped on collision.
    say_with_time "Backfilling form_templates.reference_prefix" do
      used = Set.new
      FormTemplate.reset_column_information
      FormTemplate.where(reference_prefix: [ nil, "" ]).order(:id).each do |template|
        seed = FormReference::PREFIX_SEEDS[template.class_name] ||
               FormReference.derive_prefix(template.class_name)
        prefix = unique_prefix(seed, used)
        used << prefix.upcase
        template.update_columns(reference_prefix: prefix)
      end
    end

    add_index :form_templates, :reference_prefix, unique: true,
              where: "reference_prefix IS NOT NULL",
              name: "index_form_templates_on_reference_prefix"
  end

  def down
    remove_index :form_templates, name: "index_form_templates_on_reference_prefix"
    remove_column :form_templates, :reference_prefix
  end

  private

  # Append 2, 3, ... to a candidate until it isn't already taken.
  def unique_prefix(candidate, used)
    return candidate unless used.include?(candidate.upcase)

    suffix = 2
    suffix += 1 while used.include?("#{candidate}#{suffix}".upcase)
    "#{candidate}#{suffix}"
  end
end

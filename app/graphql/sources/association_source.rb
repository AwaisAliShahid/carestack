# frozen_string_literal: true

module Sources
  # Source for batch loading has_many associations
  class AssociationSource < GraphQL::Dataloader::Source
    def initialize(model_class, association_name)
      super()
      @model_class = model_class
      @association_name = association_name
    end

    def fetch(records)
      ::ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: @association_name
      ).call

      records.map { |record| record.public_send(@association_name) }
    end
  end
end

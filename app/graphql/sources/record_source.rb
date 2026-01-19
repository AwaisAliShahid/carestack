# frozen_string_literal: true

module Sources
  # Generic source for batch loading records by ID
  class RecordSource < GraphQL::Dataloader::Source
    def initialize(model_class, column: :id)
      super()
      @model_class = model_class
      @column = column
    end

    def fetch(ids)
      records = @model_class.where(@column => ids).index_by(&@column)
      ids.map { |id| records[id] }
    end
  end
end

# frozen_string_literal: true

module Sources
  # Source for batch loading association counts
  class CountSource < GraphQL::Dataloader::Source
    def initialize(model_class, foreign_key)
      super()
      @model_class = model_class
      @foreign_key = foreign_key
    end

    def fetch(ids)
      counts = @model_class
        .where(@foreign_key => ids)
        .group(@foreign_key)
        .count

      ids.map { |id| counts[id] || 0 }
    end
  end
end

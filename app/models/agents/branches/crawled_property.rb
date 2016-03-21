module Agents
  module Branches
    class CrawledProperty < ActiveRecord::Base
      belongs_to :branch, class_name: 'Agents::Branch'
    end
  end
end


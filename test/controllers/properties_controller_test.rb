require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
require_relative '../helpers/udprn_helper'
require_relative '../helpers/agents_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class PropertiesControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  include UdprnHelper
  include AgentsHelper

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    sleep(1)
  end


  def teardown
    delete_all_docs
  end
end
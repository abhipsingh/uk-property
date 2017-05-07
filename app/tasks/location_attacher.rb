module LocationAttacher
  def self.attach_location_attrs_to_zoopla_buy(from, to)
    counter = 0
    Agents::Branches::CrawledProperty.where("id > ?", from).where(post_town: nil).where("id < ?", to).where.not(postcode: nil).select([:id,:postcode]).each do |property|
      prop = Uk::Property.fuzzy_search(post_code: property.postcode).first
      if prop
        #td = prop.thoroughfare_descriptor
        td = nil
        dtd = nil
        ddl = prop.double_dependent_locality
        dl = prop.dependent_locality
        pt = prop.post_town
        #dtd = prop.dependent_thoroughfare_description
        Agents::Branches::CrawledProperty.where(id: property.id).update_all({thoroughfare_descriptor: td, double_dependent_locality: ddl, dependent_locality: dl, post_town: pt, dependent_thoroughfare_description: dtd})
        #Uk::Property.connection.execute("UPDATE agents_branches_crawled_properties SET thoroughfare_descriptor='#{td}', double_dependent_locality='#{ddl}', dependent_locality='#{dl}', post_town='#{pt}', dependent_thoroughfare_description='#{dtd}' WHERE id='#{prop.id}'")
      end
      p "#{counter} PASS" #if counter == 100
      counter  = 0 if counter == 100
      counter += 1
    end
  end

  def self.attach_location_attrs_to_otm_buy(from, to)
    counter = 0
    Agents::Branches::CrawledProperties::Buy.where("id > ?", from).where(post_town: nil).where("id < ?", to).where.not(postcode: nil).select([:id,:postcode]).each do |property|
      prop = Uk::Property.fuzzy_search(post_code: property.postcode).first
      if prop
        td = prop.thoroughfare_descriptor
        ddl = prop.double_dependent_locality
        dl = prop.dependent_locality
        pt = prop.post_town
        dtd = prop.dependent_thoroughfare_description
        td = nil
        dtd = nil
        Agents::Branches::CrawledProperties::Buy.where(id: property.id).update_all({thoroughfare_descriptor: td, double_dependent_locality: ddl, dependent_locality: dl, post_town: pt, dependent_thoroughfare_description: dtd})
        #Uk::Property.connection.execute("UPDATE agents_branches_crawled_properties_buys SET thoroughfare_descriptor='#{td}', double_dependent_locality='#{ddl}', dependent_locality='#{dl}', post_town='#{pt}', dependent_thoroughfare_description='#{dtd}' WHERE id='#{prop.id}'")
      end
      p "#{counter} PASS"# if counter == 100
      counter  = 0 if counter == 100
      counter += 1
    end
  end

  def self.attach_location_attrs_to_otm_rent(from, to)
    counter = 0
    Agents::Branches::CrawledProperties::Rent.where("id > ?", from).where(post_town: nil).where("id < ?", to).where.not(postcode: nil).select([:id,:postcode]).each do |property|
      prop = Uk::Property.fuzzy_search(post_code: property.postcode).first
      if prop
        td = prop.thoroughfare_descriptor
        ddl = prop.double_dependent_locality
        dl = prop.dependent_locality
        pt = prop.post_town
        dtd = prop.dependent_thoroughfare_description
        td = nil
        dtd = nil
        Agents::Branches::CrawledProperties::Rent.where(id: property.id).update_all({thoroughfare_descriptor: td, double_dependent_locality: ddl, dependent_locality: dl, post_town: pt, dependent_thoroughfare_description: dtd})
        #Uk::Property.connection.execute("UPDATE agents_branches_crawled_properties_rents SET thoroughfare_descriptor='#{td}', double_dependent_locality='#{ddl}', dependent_locality='#{dl}', post_town='#{pt}', dependent_thoroughfare_description='#{dtd}' WHERE id='#{prop.id}'")
      end
      p "#{counter} PASS" #if counter == 100
      counter  = 0 if counter == 100
      counter += 1
    end
  end
end


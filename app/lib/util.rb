module Util

  def compute_postcode_units(postcode)
    district_part, sector_part = postcode.split(' ')
    district_match = district_part.match(/([A-Z]{0,3})([0-9]{0,3}[A-Z]{0,2})/)
    area = ''
    area = district_match[1] if district_part && !district_match[1].empty?
    district = ''
    district = district_match[1] + district_match[2] if district_part && !district_match[1].empty? && !district_match[2].empty?
    sector_match = sector_part.match(/([0-9]{0,3})([A-Z]{0,3})/) if sector_part
    sector_half = sector_match[1] if sector_part
    sector = ''
    sector = district + ' ' + sector_half.to_s if sector_half
    unit = ''
    unit = district_part + ' ' + sector_match[1] + sector_match[2] if sector_part && !sector_match[1].empty? && !sector_match[2].empty?
    return area, district, sector, unit
  end

end
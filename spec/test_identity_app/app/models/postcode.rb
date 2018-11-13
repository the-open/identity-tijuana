class Postcode < ApplicationRecord
  include ReadWriteIdentity
  if Settings.databases.zip_schema
    self.table_name = "#{Settings.databases.zip_schema}.zips"
  end
  if Settings.databases.zip_primary_key
    self.primary_key = Settings.databases.zip_primary_key
  end

  def self.nearest_postcode(latitude, longitude)
    where("ST_Intersects(geom, ST_Buffer(ST_GeomFromText('POINT(#{longitude} #{latitude})', 4326), 0.05))").take(1).first
  end

  def zip
    self.id
  end

  def self.search(zip)
    zip ||= ''
    cleaned_zip = zip.strip.upcase.gsub(/[^0-9a-z-]/i, '')
    unless Settings.geography.postcode_dash
      cleaned_zip = cleaned_zip.gsub(/-/, '')
    end
    where(self.primary_key => cleaned_zip).first
  end

  def outcode
    zip.reverse[3..-1].reverse
  end
end

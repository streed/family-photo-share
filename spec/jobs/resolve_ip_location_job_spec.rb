require "rails_helper"

RSpec.describe ResolveIpLocationJob do
  it "caches the place an address resolves to" do
    allow(IpGeolocationLookup).to receive(:call).and_return(
      IpGeolocationLookup::Result.new(
        status: "ok", city: "Portland", region: "Oregon", country: "United States",
        country_code: "US", latitude: "45.52", longitude: "-122.68", provider: "ipwho.is"
      )
    )

    described_class.perform_now("8.8.8.8")

    location = IpLocation.find_by(ip_address: "8.8.8.8")
    expect(location).to be_resolved
    expect(location.label).to eq("Portland, Oregon, United States")
    expect(location.latitude).to eq(45.52)
    expect(location.resolved_at).to be_present
  end

  it "records a failed lookup so the address is not retried on every page view" do
    allow(IpGeolocationLookup).to receive(:call).and_return(IpGeolocationLookup::Result.new(status: "failed"))

    described_class.perform_now("8.8.8.8")

    expect(IpLocation.find_by(ip_address: "8.8.8.8").status).to eq("failed")
  end

  it "leaves a fresh answer alone" do
    IpLocation.create!(ip_address: "8.8.8.8", status: "ok", city: "Portland", resolved_at: 1.hour.ago)
    expect(IpGeolocationLookup).not_to receive(:call)

    described_class.perform_now("8.8.8.8")
  end
end

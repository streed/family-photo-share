require "rails_helper"

RSpec.describe IpGeolocationLookup do
  describe ".call" do
    it "marks loopback and LAN addresses as private without calling out" do
      expect_any_instance_of(described_class).not_to receive(:get)

      %w[127.0.0.1 192.168.1.10 10.0.0.4 ::1].each do |ip|
        expect(described_class.call(ip).status).to eq("private")
      end
    end

    it "returns a failed result for a blank address" do
      expect(described_class.call("").status).to eq("failed")
    end

    it "maps an ipwho.is response onto a result" do
      allow_any_instance_of(described_class).to receive(:get).and_return(
        "success" => true,
        "city" => "Portland",
        "region" => "Oregon",
        "country" => "United States",
        "country_code" => "US",
        "postal" => "97205",
        "timezone" => { "id" => "America/Los_Angeles" },
        "latitude" => 45.52,
        "longitude" => -122.68
      )

      result = described_class.call("8.8.8.8")

      expect(result.status).to eq("ok")
      expect(result.city).to eq("Portland")
      expect(result.region).to eq("Oregon")
      expect(result.country).to eq("United States")
      expect(result.country_code).to eq("US")
      expect(result.timezone).to eq("America/Los_Angeles")
      expect(result.latitude).to eq(45.52)
      expect(result.provider).to eq("ipwho.is")
    end

    it "falls back to the next provider when the first one fails" do
      call_count = 0
      allow_any_instance_of(described_class).to receive(:get) do
        call_count += 1
        call_count == 1 ? { "success" => false } : { "city" => "Bend", "country_name" => "United States", "country_code" => "US" }
      end

      result = described_class.call("8.8.8.8")

      expect(result.status).to eq("ok")
      expect(result.city).to eq("Bend")
      expect(result.provider).to eq("ipapi.co")
    end

    it "reports failure rather than raising when every provider errors" do
      allow_any_instance_of(described_class).to receive(:get).and_raise(Errno::ECONNREFUSED)

      expect(described_class.call("8.8.8.8").status).to eq("failed")
    end
  end
end

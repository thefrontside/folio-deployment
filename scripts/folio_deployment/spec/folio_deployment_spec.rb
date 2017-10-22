require "spec_helper"

RSpec.describe FolioDeployment do
  it "has a version number" do
    expect(FolioDeployment::VERSION).not_to be nil
  end
end

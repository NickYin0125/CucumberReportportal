# frozen_string_literal: true

Given("a user exists") do
  rp_log("Seed user record")
  rp_attach("fixture-image", name: "seed.txt", mime: "text/plain", message: "Seed attachment")
end

When("the user logs in") do
  rp_step("Authenticate user") do
    rp_log("Submitting credentials")
  end
end

Then("the login succeeds") do
  rp_log("Login completed")
end

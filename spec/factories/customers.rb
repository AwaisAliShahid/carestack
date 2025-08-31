FactoryBot.define do
  factory :customer do
    account { nil }
    first_name { "MyString" }
    last_name { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    address { "MyText" }
  end
end

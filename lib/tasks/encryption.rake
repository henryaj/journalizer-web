namespace :encryption do
  desc "Encrypt all existing unencrypted records"
  task migrate: :environment do
    models_with_attrs = {
      User => [:email_address, :name, :stripe_customer_id],
      JournalEntry => [:title, :content],
      JobPage => [:raw_ocr_text],
      Session => [:ip_address]
    }

    models_with_attrs.each do |model, encrypted_attrs|
      count = 0
      encrypted_count = 0
      puts "Encrypting #{model.name}..."

      model.find_each do |record|
        needs_encryption = false

        encrypted_attrs.each do |attr|
          raw_value = record.read_attribute_before_type_cast(attr)
          next if raw_value.blank?

          # Check if value is already encrypted (starts with JSON object)
          unless raw_value.to_s.start_with?("{")
            needs_encryption = true
            # Force the attribute to be marked as changed
            record.send("#{attr}_will_change!")
          end
        end

        if needs_encryption
          record.save!(touch: false)
          encrypted_count += 1
        end
        count += 1
        print "." if (count % 100).zero?
      end

      puts "\n  Done: #{count} records (#{encrypted_count} encrypted)"
    end

    puts "\nEncryption migration complete!"
    puts "You can now set SUPPORT_UNENCRYPTED_DATA=false"
  end
end

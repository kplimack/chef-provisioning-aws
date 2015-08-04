require 'chef/provisioning/aws_driver/aws_provider'

class Chef::Provider::AwsDbSubnetGroup < Chef::Provisioning::AWSDriver::AWSProvider

  def create_aws_object
    converge_by "create new DB Subnet Group #{new_resource.name} in #{region}"do
      driver.create_db_subnet_group(desired_options)
    end
  end

  def destroy_aws_object(object)
    converge_by "delete DB Subnet Group #{new_resource.name} in #{region}" do
      driver.delete_db_subnet_group(db_subnet_group_name: new_resource.db_subnet_group_name)
    end
  end

  def update_aws_object(object)
    updates = required_updates(object)
    if ! updates.empty?
      converge_by updates do
        driver.modify_db_subnet_group(desired_options)
      end
    end
  end

  def desired_options
    opts = {}
    opts[:db_subnet_group_name] = new_resource.db_subnet_group_name
    opts[:db_subnet_group_description] = new_resource.db_subnet_group_description
    opts[:subnet_ids] = new_resource.subnet_ids
    opts[:tags] = tag_hash_to_array(new_resource.aws_tags) if new_resource.aws_tags
    opts
  end

  # Given an existing object, return an array of update descriptions
  # representing the updates that need to be made.
  #
  # If no updates are needed, an empty array is returned.
  #
  def required_updates(object)
    ret = []
    if desired_options[:db_subnet_group_description] != object[:db_subnet_group_description]
      ret << "  set group description to #{desired_options[:db_subnet_group_description]}"
    end

    if ! xor_array(desired_options[:subnet_ids], subnet_ids(object[:subnets])).empty?
      pp desired_options[:subnet_ids]
      pp object[:subnets]
      ret << "  set subnets to #{desired_options[:subnet_ids]}"
    end

    if ! (desired_options[:tags].nil? || desired_options[:tags].empty?)
      # modify_db_subnet_group doesn't support the tags key according to
      # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/RDS/Client.html#modify_db_subnet_group-instance_method
      Chef::Log.warn "Updating tags for DB subnet groups is not supported."
    end

    ret.unshift("update DB Subnet Group #{new_resource.name} in #{region}") unless ret.empty?
    ret
  end


  private

  def subnet_ids(subnets)
    subnets.map {|i| i[:subnet_identifier] }
  end

  def xor_array(a, b)
    (a | b) - (a & b)
  end

  # To be in line with the other resources. The aws_tags property
  # takes a hash.  But we actually need an array.
  def tag_hash_to_array(tag_hash)
    ret = []
    tag_hash.each do |key, value|
      ret << {:key => key, :value => value}
    end
    ret
  end

  def driver
    new_resource.driver.rds.client
  end
end

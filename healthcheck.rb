cred = JSON::parse open('/usr/local/nginx/conf/aws_credentials.json').read
server_map = JSON::parse open('/usr/local/nginx/conf/server_map.json').read
servers = server_map['upstream'].inject({}) {|r, h| r[h['name']] = h; r}

metric_query = server_map['upstream'].map.with_index do |s, idx|
  {
    'Id' => "m#{idx + 1}",
    'MetricStat' =>  {
      'Metric' =>  {
        'Namespace' =>  'AWS/RDS',
        'MetricName' =>  'ReplicaLag',
        'Dimensions' =>  [{
          'Name' => 'DBInstanceIdentifier',
          'Value' =>  s['name']
        }]
      },
      'Period' =>  60,
      'Stat' =>  'Average'
    }
  }
end

client = AWS::CloudWatch::Client.new(cred['apikey'], cred['apisecret'], cred['region'])
redis = Redis.new 'redis', 6379

loop do
  begin
    result = client.get_metric_data Time.now - 60, Time.now, metric_query
    if result.code == 200
      response = JSON::parse(result.body)
      metrics = response['GetMetricDataResponse']['GetMetricDataResult']['MetricDataResults']
      p metrics
      metrics.each do |e|
        servers[e['Label']]['lag'] = e['Values'].first
      end
      redis.set 'upstreams', JSON::stringify(servers.select{|k,h| h['lag'] < 30}.values.map{|e| e['endpoint']}) 
    else
      puts 'Error: Health check failed' 
    end
    sleep 30
  rescue => e
    p e
  end
end


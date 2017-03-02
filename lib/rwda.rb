require "rwda/version"
require "httparty"
require "json"
require "test/unit"

class Browser
  include Test::Unit::Assertions

  def initialize (enable_debugger = false)
    @enable_debugger = enable_debugger
  end

  def wait_for_response(request_route, request_type, body, lamb, timeout=10)
    start = Time.now
    while Time.now - start < timeout
      case request_type
        when 'post'
          val = HTTParty.post(request_route, :body => body.to_json)
        when 'get'
          val = HTTParty.get(request_route)
        when 'delete'
          val = HTTParty.delete(request_route, :body => body.to_json)
      end
      if lamb.call(val.to_json)
        return val.to_json
      end
      sleep 1
    end
  end

  def wait_for_network_connection_done(timeout=30)
    request_route = @url+'/'+@session_id+'/elements'
    body = {:using => 'xpath', :value => "XCUIElementTypeOther[@label='Network connection in progress']"}
    sleep 1
    start = Time.now
    while Time.now - start < timeout
      val = HTTParty.post(request_route, :body => body.to_json)
      if JSON.parse(val.to_json)['value'].size == 0
        return
      end
      sleep 1
    end
    sleep 1
  end

  def send_request(request_route, request_type, body)
    case request_type
      when 'post'
        val = HTTParty.post(request_route, :body => body.to_json)
      when 'get'
        val = HTTParty.get(request_route)
      when 'delete'
        val = HTTParty.delete(request_route, :body => body.to_json)
    end
    p "The sending request is #{val}" if @enable_debugger
    return val.to_json
  end

  def wait_element_enable(element)
    request_route = @url+'/'+@session_id+'/element/'+element+'/enabled'
    wait_for_response(request_route, 'get', '', lambda { |val| return val.to_json.include? 'true' })
  end

  def wait_element_display(element)
    request_route = @url+'/'+@session_id+'/element/'+element+'/displayed'
    wait_for_response(request_route, 'get', '', lambda { |val| return val.to_json.include? 'true' })
  end

  def open_app(device, bundle_id = 'com.rea-group.reapa.internal')
    app_body = {:desiredCapabilities => {:bundleId => bundle_id}}
    response = HTTParty.post(DEVICE_URL[device], :body => app_body.to_json)
    @url = DEVICE_URL[device]
    @session_id = response['sessionId']
  end

  def clean_keychain(device)
    system(COMMAND_PATH + ' ' + DEVICE_INFO[device] +' clear_keychain ' + BUNDLE_ID)
  end

  def install_app(device)
    system(COMMAND_PATH + ' ' + DEVICE_INFO[device] +' install ' + APP_PATH)
  end

  def uninstall_app(device)
    system(COMMAND_PATH + ' ' + DEVICE_INFO[device] +' uninstall ' + BUNDLE_ID)
  end

  def find_elements_by_class(class_val, label='null', recall=false, exception='Element was not found！')
    wait_for_network_connection_done
    body = {:using => 'class name', :value => class_val}
    request_route = @url+'/'+@session_id+'/elements'
    if recall
      response = wait_for_response(request_route, 'post', body, lambda { |val| return (val.include? class_val) && (val.include? label) })
    else
      response = send_request(request_route, 'post', body)
    end

    response = JSON.parse(response)
    p "Finding elements by class. The response is #{response}" if @enable_debugger

    if label == 'null'
      response = response['value'].find_all { |item| item['label'] == nil }
    else
      response = response['value'].find_all { |item| item['label'] == label }
    end

    response
  end

  def find_elements_by_xpath(xpath, recall=false, exception='Element was not found！')
    wait_for_network_connection_done
    body = {:using => 'xpath', :value => xpath}
    request_route = @url+'/'+@session_id+'/elements'
    if recall
      response = wait_for_response(request_route, 'post', body, lambda { |val| return (JSON.parse(val)['value'].length > 0) && !(val.include? 'Cannot evaluate results for XPath expression') })
    else
      response = send_request(request_route, 'post', body)
    end
    response = JSON.parse(response)
    p "Finding elements by xpath. The response is #{response}" if @enable_debugger
    response = response['value']
    raise exception if response == nil
    response
  end

  def tap_element(element_id)
    request_route = @url+'/'+@session_id+'/element/'+element_id+'/click'
    send_request(request_route, 'post', '')
  end

  def type_text(element_id, val)
    request_route_clear = @url+'/'+@session_id+'/element/'+element_id+'/clear'
    send_request(request_route_clear, 'post', '')
    request_route_type = @url+'/'+@session_id+'/element/'+element_id+'/value'
    body = {:value => val}
    send_request(request_route_type, 'post', body)
  end

  def type_text_without_clear(element_id, val)
    request_route_type = @url+'/'+@session_id+'/element/'+element_id+'/value'
    body = {:value => val}
    send_request(request_route_type, 'post', body)
  end

  def scroll_to_element(name, element_id)
    request_route = @url+'/'+@session_id+'/wda/Element/'+element_id+'/scroll'
    body = {:name => name}
    send_request(request_route, 'post', body)
  end

  def take_screenshot(to_file: './screenshot.png')
    request_route = @url+'/screenshot'
    response = wait_for_response(request_route, 'get', '', lambda { |val| return val.to_s.include? @session_id })
    File.write to_file, Base64.decode64(response['value'])
    response['output'] = to_file
    response
  end

  def swipe_element_with_direction(element_id, direction)
    request_route = @url+'/'+@session_id+'/wda/element/'+element_id+'/swipe'
    body = {:direction => direction}
    send_request(request_route, 'post', body)
  end

  def get_element_value(element_id)
    request_route = @url+'/'+@session_id+'/element/'+element_id+'/attribute/value'
    wait_for_response(request_route, 'get', '', lambda { |val| return val.to_s.include? @session_id })
  end

  def get_element_rect(element_id)
    request_route = @url+'/'+@session_id+'/element/'+element_id+'/attribute/rect'
    wait_for_response(request_route, 'get', '', lambda { |val| return val.to_s.include? @session_id })
  end

  def background_app
    url = @url.gsub('/session', '')
    request_route = url+'/wda/homescreen'
    wait_for_response(request_route, 'post', '', lambda { |val| return val.to_s.include? @session_id })
  end

end
class StockAlertWorker 
   include Sidekiq::Worker
   sidekiq_options :retry => false 

  def perform
    list_of_stock_to_watch_out_for = ["ACC","ADANIENT","ADANIPORTS","ADANIPOWER","AJANTPHARM","ALBK","AMARAJABAT","AMBUJACEM","ANDHRABANK","APOLLOHOSP","APOLLOTYRE","ARVIND","ASHOKLEY","ASIANPAINT","AUROPHARMA","AXISBANK","AUTO","BAJFINANCE","BAJAJFINSV","BALKRISIND","BALRAMCHIN","BANKBARODA","BANKINDIA","BATAINDIA","BEML","BERGEPAINT","BEL","BHARATFIN","BHARATFORG","BPCL","BHARTIARTL","INFRATEL","BHEL","BIOCON","BOSCHLTD","BRITANNIA","CADILAHC","CANFINHOME","CANBK","CAPF","CASTROLIND","CEATLTD","CENTURYTEX","CESC","CGPOWER","CHENNPETRO","CHOLAFIN","CIPLA","COALINDIA","COLPAL","CONCOR","CUMMINSIND","DABUR","DALMIABHA","DCBBANK","DHFL","DISHTV","DIVISLAB","DLF","DRREDDY","EICHERMOT","ENGINERSIN","EQUITAS","ESCORTS","EXIDEIND","FEDERALBNK","FORTIS","GAIL","GLENMARK","GMRINFRA","GODFRYPHLP","GODREJCP","GODREJIND","GRANULES","GRASIM","GSFC","HAVELLS","HCLTECH","HDFCBANK","HDFC","HEROMOTOCO","HEXAWARE","HINDALCO","HCC","HINDPETRO","HINDUNILVR","HINDZINC","HDIL","ICICIBANK","ICICIPRULI","IDBI","IDEA","IDFCBANK","IDFC","IFCI","IBULHSGFIN","IBREALEST","INDIANB","IOC","ICIL","IGL","INDUSINDBK","INFIBEAM","INFY","INDIGO","IRB","ITC","JISLJALEQS","JPASSOCIAT","JETAIRWAYS","JINDALSTEL","JSWENERGY","JSWSTEEL","JUBLFOOD","KAJARIACER","KTKBANK","KSCL","KOTAKBANK","KPIT","TFH","LT","LICHSGFIN","LUPIN","MFIN","MGL","M","MANAPPURAM","MRPL","MARICO","MARUTI","MFSL","MINDTREE","MOTHERSUMI","MRF","MCX","MUTHOOTFIN","NATIONALUM","NBCC","NCC","NESTLEIND","NHPC","NIITTECH","NMDC","NTPC","ONGC","OIL","OFSS","ORIENTBANK","PAGEIND","PCJEWELLER","PETRONET","PIDILITIND","PEL","PFC","POWERGRID","PTC","PNB","PVR","RAYMOND","RBLBANK","RELCAPITAL","RCOM","RNAVAL","RELIANCE","RELINFRA","RPOWER","REPCOHOME","RECLTD","SHREECEM","SRTRANSFIN","SIEMENS","SREINFRA","SRF","SBIN","SAIL","STAR","SUNPHARMA","SUNTV","SUZLON","SYNDIBANK","TATACHEM","TATACOMM","TCS","TATAELXSI","TATAGLOBAL","TATAMTRDVR","TATAMOTORS","TATAPOWER","TATASTEEL","TECHM","INDIACEM","RAMCOCEM","SOUTHBANK","TITAN","TORNTPHARM","TORNTPOWER","TV18BRDCST","TVSMOTOR","ULTRACEMCO","UNIONBANK","UBL","N","UPL","VEDL","VGUARD","VOLTAS","WIPRO","WOCKPHARMA","YESBANK","ZEEL"]
    exclude_list = ["UJJIVAN", "JUSTDIAL", "JPASSOCIAT"]
#    if ((Time.now.hour >= 3) && (Time.now.hour < 10 || (Time.now.hour == 10 && Time.now.min < 30)))
#      #StockAlertWorker.perform_in(10.seconds)
#    elsif (Time.now.hour == 10 && Time.now.min == 30)
#      #StockAlertWorker.perform_in(1050.minutes.from_now)
#    end
    resp = Oj.load(Net::HTTP.get(URI.parse("https://www.nseindia.com/live_market/dynaContent/live_watch/stock_watch/foSecStockWatch.json"))) rescue nil
    ardb_client = Rails.configuration.ardb_client
    stocks_in_list = []
    if resp
      resp['data'].each do |t|
        if !exclude_list.include?(t["symbol"])
          last_price = ardb_client.hget("stock_prices", t["symbol"]) 
          last_price ||= 0
          last_price = last_price.to_f 
          current_price = t['ltP'].gsub(/[0-9\.]+/).to_a.join("").to_f
          change = (((current_price - last_price)/(last_price)) * 100).round(2)
          if change > 0.7 || change < -0.7
            stocks_in_list.push({name: t['symbol'], change: change, price: t['ltP']})
          end
          ardb_client.hset("stock_prices", t["symbol"], current_price)
        end
      end
      StockMailer.alert_email(stocks_in_list).deliver_now if !stocks_in_list.empty?
    end
  end

end


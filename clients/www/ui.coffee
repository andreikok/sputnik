$ ->
    location = window.location
    hostname = location.hostname
    protocol = location.protocol
    if protocol == 'http:'
        ws_protocol = "ws:"
    else
        ws_protocol = "wss:"

    uri = ws_protocol + "//" + hostname + ":8000"
    # REMOVE THIS IF NOT TESTING VS DEMO
    uri = "wss://demo.m2.io:8000"

    sputnik = new Sputnik uri
    window.sputnik = sputnik

    $.ajax {
            url: 'index_template.html'
            success: (data, status, xhr) ->
                start(data)
            }

    start = (template) ->
        ractive = new Ractive
            el: "target"
            template: template
            data:
                sputnik: sputnik
                current_ticker: null
                current_type: null
                current_currency: null
                current_page: "dashboard"
                dashboard_tab: "active-contracts"
                account_tab: "profile"
                fh_tab: "deposit"
                tb_tab: "trades"
                audit_tab: "Liability"
                audit_contract: "BTC"
                type_alias:
                    "cash_pair": "Cash"
                    "prediction": "Predictions"
                    "futures": "Futures"
                format_time: (datetime) ->
                    if datetime?
                        new Date(datetime/1000).toLocaleString()
                clean_ticker: (ticker) ->
                    ticker.replace('/', '_')
            transitions:
                show_chart: (t, ticker) ->
                    showChart(ticker, t.node.id)

            adapt: [Ractive.adaptors.Sputnik]
            debug: true

        ractive.on
            switch_type: (event, type) ->
                event.original.preventDefault()
                ractive.set "current_type", type

            switch_contract: (event) ->
                event.original.preventDefault()
                ractive.set "current_ticker", event.context

            switch_currency: (event, currency) ->
                event.original.preventDefault()
                ractive.set "current_currency", currency
                sputnik.getAddress(currency)
                sputnik.getDepositInstructions(currency)

            switch_page: (event, page) ->
                event.original.preventDefault()
                ractive.set "current_page", page
                if page is "trade" and ractive.get("current_ticker") is null
                    markets = ractive.get("sputnik.markets")
                    tickers = Object.keys(markets)
                    if tickers.length
                        ractive.set("current_ticker", tickers[0])
                        ractive.set("current_type", markets[tickers[0]].contract_type)
                if page is "account" and ractive.get("sputnik.logged_in") is false
                    $('#login_modal').modal()

            switch_dashboard_tab: (event, tab) ->
                event.original.preventDefault()
                ractive.set "dashboard_tab", tab

            switch_account_tab: (event, tab) ->
                event.original.preventDefault()
                ractive.set "account_tab", tab
                if tab == "audit"
                    sputnik.getAudit()

            switch_fh_tab: (event, tab) ->
                event.original.preventDefault()
                ractive.set "fh_tab", tab

            switch_tb_tab: (event, tab) ->
                event.original.preventDefault()
                ractive.set "tb_tab", tab

            switch_audit_tab: (event, tab) ->
                event.original.preventDefault()
                ractive.set "audit_tab", tab

            switch_audit_contract: (event, ticker) ->
                event.original.preventDefault()
                ractive.set "audit_contract", ticker

            withdraw: (event, type) ->
                event.original.preventDefault()
                ticker = ractive.get("current_currency")
                amount = Number($('#withdraw-amount').val())
                if type == "crypto"
                    address = $('#crypto_address').val()
                    confirm_address = $('#crypto_confirm_address').val()
                    if address != confirm_address
                        bootbox.alert "Addresses do not match"
                        return
                else if type == "wire"
                    address_obj =
                        bank_name: $('#withdraw-bank-name').val()
                        bank_address: $('#withdraw-bank-address').val()
                        aba_swift: $('#withdraw-aba-swift').val()
                        account_name: $('#withdraw-account-name').val()
                        account_number: $('#withdraw-account-number').val()
                    address = JSON.stringify(address_obj)
                else
                    address_obj =
                        name: $('#withdraw-name').val()
                        address1: $('#withdraw-address1').val()
                        address2: $('#withdraw-address2').val()
                        city: $('#withdraw-city').val()
                        state_province: $('#withdraw-state').val()
                        postalcode: $('#withdraw-postalcode').val()
                        country: $('#withdraw-country').val()
                    address = JSON.stringify(address_obj)

                sputnik.requestWithdrawal(ticker, amount, address)

            buykey: (event) ->
                buy_price_str = $('#buy_price').val()
                if buy_price_str == ''
                    buy_price_str = ractive.get("sputnik.books")[ractive.get("current_ticker")].best_ask.price

                buy_price = Number(buy_price_str)

                if not sputnik.canPlaceOrder(Number($("#buy_quantity").val()), buy_price, ractive.get("current_ticker"), 'BUY')
                    $("#buy_alert").show()
                    $("#buyButton").hide()
                else
                    $("#buy_alert").hide()
                    $("#buyButton").show()

            sellkey: (event) ->
                sell_price_str = $('#sell_price').val()
                if sell_price_str == ''
                    sell_price_str = ractive.get("sputnik.books")[ractive.get("current_ticker")].best_bid.price

                sell_price = Number(sell_price_str)
                if not sputnik.canPlaceOrder(Number($("#sell_quantity").val()), sell_price, ractive.get("current_ticker"), 'SELL')
                    $("#sell_alert").show()
                    $("#sellButton").hide()
                else
                    $("#sell_alert").hide()
                    $("#sellButton").show()

            buy: (event) ->
                event.original.preventDefault()
                buy_quantity = Number($('#buy_quantity').val())
                buy_price_str = $("#buy_price").val()

                if buy_quantity <= 0
                    bootbox.alert "Invalid quantity"
                    return true

                if buy_price_str == ''
                    buy_price_str = ractive.get("sputnik.books")[ractive.get("current_ticker")].best_ask.price
                    bootbox.confirm "Placing order with price: #{buy_price_str}.\n\nAre you sure?", (result) =>
                        if result
                            sputnik.placeOrder(buy_quantity, Number(buy_price_str), ractive.get("current_ticker"), 'BUY')
                else
                    buy_price = Number(buy_price_str)
                    if buy_price <= 0
                        bootbox.alert "Invalid price"
                        return true

                    if not withinAnOrderOfMagnitude(buy_price, ractive.get("sputnik.books")[ractive.get("current_ticker")].best_ask.price)
                        bootbox.confirm 'This price is significantly different from the latest market price.\n\nAre you sure you want to execute this trade?', (result) ->
                            if result
                                sputnik.placeOrder(buy_quantity, buy_price, ractive.get("current_ticker"), 'BUY')
                    else
                        sputnik.placeOrder(buy_quantity, buy_price, ractive.get("current_ticker"), 'BUY')

            sell: (event) ->
                event.original.preventDefault()
                sell_quantity = Number($('#sell_quantity').val())
                sell_price_str = $("#sell_price").val()


                if sell_quantity <= 0
                    bootbox.alert "Invalid quantity"
                    return true

                if sell_price_str == ''
                    sell_price_str = ractive.get("sputnik.books")[ractive.get("current_ticker")].best_bid.price
                    bootbox.confirm "Placing order with price: #{sell_price_str}.\n\nAre you sure?", (result) =>
                        if result
                            sputnik.placeOrder(sell_quantity, Number(sell_price_str), ractive.get("current_ticker"), 'SELL')
                else
                    sell_price = Number(sell_price_str)
                    if sell_price <= 0
                        bootbox.alert "Invalid price"

                    if not withinAnOrderOfMagnitude(sell_price, ractive.get("sputnik.books")[ractive.get("current_ticker")].best_bid.price)
                        bootbox.confirm 'This price is significantly different from the latest market price.\n\nAre you sure you want to execute this trade?', (result) ->
                            if result
                                sputnik.placeOrder(sell_quantity, sell_price, ractive.get("current_ticker"), 'SELL')
                    else
                        sputnik.placeOrder(sell_quantity, sell_price, ractive.get("current_ticker"), 'SELL')

            transactions: (event) ->
                event.original.preventDefault()
                sputnik.log ["get_history", $("#transactions_start_date").val(), $("#transactions_end_date").val()]
                start_timestamp = Date.parse($("#transactions_start_date").val()) * 1000
                end_timestamp = Date.parse($("#transactions_end_date").val()) * 1000
                now = new Date()
                if isNaN start_timestamp
                    start = new Date()
                    start.setDate(now.getDate() - 7)
                    start_timestamp = start.getTime() * 1000
                    $('#transactions_start_date').val(start.toDateString())
                if isNaN end_timestamp
                    end = new Date()
                    end.setDate(now.getDate())
                    end_timestamp = end.getTime() * 1000
                    $('#transactions_end_date').val(end.toDateString())

                sputnik.getTransactionHistory(start_timestamp, end_timestamp)

            submit_compliance: (event) ->
                event.original.preventDefault()
                compliance_client_handler($('#compliance form').eq(0))

            change_profile: (event) ->
                event.original.preventDefault()
                sputnik.changeProfile(ractive.get("sputnik.profile.email"), ractive.get("sputnik.profile.nickname"))

            change_password: (event) ->
                event.original.preventDefault()
                if $('#new_password').val() isnt $('#new_password_confirm').val()
                    bootbox.alert "Passwords do not match"
                else
                    sputnik.changePassword $('#old_password').val(), $('#new_password_confirm').val()

            change_password_token: (event) ->
                event.original.preventDefault()
                if $('#new_password_token').val() == $('#new_password_token_confirm').val()
                    sputnik.changePasswordToken($('#new_password_token').val())
                else
                    $('#change_password_token_modal .alert').removeClass('alert-info').addClass('alert-danger').text "Passwords do not match"

            show_login_register: (event) ->
                event.original.preventDefault()
                $('#login_modal').modal()
                $("#login_modal").on 'hidden.bs.modal', ->
                    $('#register_error').hide()
                    $('#login_error').hide()
                    $('#reset_token_sent').hide()

            logout: (event) ->
                event.original.preventDefault()
                document.cookie = ''
                sputnik.logout()
                location.reload()

            cancel_order: (event, id) ->
                event.original.preventDefault()
                sputnik.cancelOrder(id)

            new_address: (event, ticker) ->
                event.original.preventDefault()
                sputnik.newAddress(ticker)

        ractive.observe "current_ticker", (new_ticker, old_ticker, path) ->
            if old_ticker?
                sputnik.unfollow old_ticker
            if new_ticker?
                sputnik.openMarket new_ticker
                showChart new_ticker

        window.ractive = ractive

        sputnik.connect()

        tv = new window.TVFeed sputnik
        window.tv = tv

        sputnik.on "log", (args...) -> ab.log args...
        sputnik.on "warn", (args...) -> ab.log args...
        sputnik.on "error", (args...) -> ab.log args...

        sputnik.on "open", () ->
            sputnik.log "open"
            $('#main_page').show()
            $('#not_connected').hide()

            # Hide stuff by default
            for page in ['trade', 'account']
                $("#page-#{page}").hide()

            # Attempt a cookie login
            full_cookie = document.cookie
            sputnik.log "full_cookie: #{full_cookie}"
            if full_cookie
                cookies = full_cookie.split(';')
                for cookie in cookies
                    field_value = cookie.trim().split("=", 2)
                    if field_value[0] == "login"
                        name_uid = field_value[1].split(":", 2)

                        if !name_uid[1]
                            sputnik.log "resetting cookie to null"
                            document.cookie = ''
                        else
                            sputnik.log "attempting cookie login with: #{name_uid[1]}"
                            sputnik.restoreSession name_uid[1]

        sputnik.on "auth_success", (username) ->
            ladda = Ladda.create $("#login_button")[0]
            ladda.stop()
            $("#login_modal").modal "hide"
            ladda = Ladda.create $("#register_button")[0]
            ladda.stop()
            $("#register_modal").modal "hide"

            sputnik.getCookie()

        sputnik.on "cookie", (uid) ->
            sputnik.log "got cookie: " + uid
            document.cookie = "login" + "=" + sputnik?.username + ":" + uid

        sputnik.on "auth_fail", (error) ->
            ladda = Ladda.create $("#login_button")[0]
            ladda.stop()
            $("#login_error").text("Incorrect username or password.").show()

        sputnik.on "make_account_success", () ->
            # do not clear the modal yet, do it in auth_success
            username = $("#register_username").val()
            password = $("#register_password").val()
            sputnik.authenticate username, password

        sputnik.on "make_account_fail", (event) ->
            ladda = Ladda.create $("#register_button")[0]
            ladda.stop()
            [code, reason] = event
            $("#register_error").text(reason)
            $("#register_error").show()

        # compropago modal success and error
        sputnik.on "compropago_deposit_success", (event) ->
          ladda = Ladda.create $("#compropago_pay_button")[0]
          ladda.stop()

          $('#compropago_confirm').text(event['note_confirmation'])
          $('#compropago_step_1').text(event['step_1'])
          $('#compropago_step_2').text(event['step_2'])
          $('#compropago_step_3').text(event['step_3'])
          $('#compropago_expiration').text(event['note_expiration_date'])
          $('#compropago_comition').text(event['note_extra_comition'])
          $('#compropago_modal').modal 'hide'
          $('#compropago_confirm_modal').modal 'show'

        sputnik.on "compropago_deposit_fail", (event) ->
          ladda = Ladda.create $('#compropago_pay_button')[0]
          ladda.stop()
          [code, reason] = event
          $('#compropago_error').text(reason)
          $('#compropago_error').show()

        $("#login_modal").keypress (e) -> $("#login_button").click() if e.which is 13

        $("#login_button").click (event) ->
            event.preventDefault()

            username = $("#login_username").val()
            password = $("#login_password").val()

            $("#login_error").hide()
            ladda = Ladda.create $("#login_button")[0]
            ladda.start()
            sputnik.authenticate username, password
            $('#login_modal .alert:visible').hide()

        $("#register_button").click (event) ->
            event.preventDefault()

            username = $("#register_username").val()
            password = $("#register_password").val()
            email = $("#register_email").val()
            nickname = $("#register_nickname").val()
            eula = $("#register_eula").is(":checked")

            if username and password and email and nickname and eula
                $('#register_error').hide()
                ladda = Ladda.create $("#register_button")[0]
                ladda.start()
                sputnik.makeAccount username, password, email, nickname
            else
                $('#register_error').text('Please complete the registration form and accept the terms and conditions to continue.').slideDown()

        withinAnOrderOfMagnitude = (x, y) ->
            sign = (number) -> if number then (if number < 0 then -1 else 1) else 0
            orderOfMag = (w) ->  sign(w) * Math.ceil(Math.log(Math.abs(w) + 1) / Math.log(10))
            orderOfMag(x) == orderOfMag(y)

        $("#compropago_pay_button").click (event) ->
            event.preventDefault()
            ladda = Ladda.create $("#compropago_pay_button")[0]
            ladda.start()
            store = $("#compropago_store").val()
            amount = $("#compropago_amount").val()
            send_sms = $("#compropago_send_sms").is(":checked")
            customer_email = $('#compropago_email').val()
            customer_phone = $('#compropago_phone').val()
            customer_phone_company = $('#compropago_phone_company').val()

            if (Number(amount) < 6000)
              sputnik.makeCompropagoDeposit store, Number(amount), customer_email, send_sms, customer_phone, customer_phone_company

        $('#chatButton').click ->
            chat_return = sputnik.chat chatBox.value
            if not chat_return[0]
                bootbox.alert chat_return[1]

            $('#chatBox').val('')

        showChart = (contract, target="tv_chart_container") ->
            sputnik.log ["Show chart", contract, target]
            options =
                fullscreen: false
                symbol: contract
                interval: "D"
                toolbar_bg: '#f4f7f9'
                allow_symbol_change: false
                container_id: target
                datafeed: window.tv
                library_path: "charting_library/"
                locale: "en"
                theme: "White"
                style: "2"
                hideideas: true
                hide_top_toolbar: true
                withdateranges: false
                details: false
                save_image: false
                show_popup_button: false
                disabled_features: ["use_localstorage_for_settings", "header_symbol_search", "header_settings", "header_indicators", "header_compare", "header_undo_redo", "header_screenshot", "header_properties", "left_toolbar"]
                enabled_features: ["narrow_chart_enabled"]
                width: '100%'
                autosize: true
                overrides:
                    "symbolWatermarkProperties.transparency": 100

            if target is "tv_chart_container"
                options.height = 480
                options.autosize = true
            else
                options.height = 240
                options.disabled_features.push "header_widget"
                options.disabled_features.push "control_bar"

            widget = new TradingView.widget options

            widget.onChartReady () ->
                sputnik.log("onChartReady")
                $("##{target} iframe").contents().find(".chart-status-picture").hide()
                if target isnt "tv_chart_container"
                    $("##{target} iframe").contents().find(".onchart-tv-logo").hide()
                    $("##{target} iframe").contents().find(".pane-legend").hide()
                    $("##{target} iframe").contents().find(".chart-controls-bar").hide()

        getFeedwind = () ->
            href = window.location.href
            css = href.substring(0, href.lastIndexOf('/')+1) + "css/feed.css"
            params =
                rssmikle_url: "http://mimeticmarkets.wordpress.com/feed/" # Later replace with ractive.get("sputnik.exchange_info.feed_uri")
                rssmikle_frame_width: "284"
                rssmikle_frame_height: "400"
                rssmikle_target: "_blank"
                rssmikle_font: "Arial, Helvetica, sans-serif"
                rssmikle_font_size: "12"
                rssmikle_border: "off"
                responsive: "on"
                rssmikle_css_url: css
                text_align: "left"
                text_align2: "left"
                corner: "off"
                scrollbar: "on"
                autoscroll: "off"
                scrolldirection: "up"
                scrollstep: "3"
                mcspeed: "20"
                sort: "New"
                rssmikle_title: "on"
                rssmikle_title_sentence: "News"
                rssmikle_title_link: ""
                rssmikle_title_bgcolor: "#33CC66"
                rssmikle_title_color: "#FFFFFF"
                rssmikle_title_bgimage: ""
                rssmikle_item_bgcolor: "#FFFFFF"
                rssmikle_item_bgimage: ""
                rssmikle_item_title_length: "55"
                rssmikle_item_title_color: "#000000"
                rssmikle_item_border_bottom: "on"
                rssmikle_item_description: "title_only"
                item_link: "on"
                rssmikle_item_description_length: "150"
                rssmikle_item_description_color: "#666666"
                rssmikle_item_date: "gl1"
                rssmikle_timezone: ""
                datetime_format: "%b %e, %Y %l:%M:%S %p"
                item_description_style: "html"
                item_thumbnail: "full"
                article_num: "15"
                rssmikle_item_podcast: "off"
                keyword_inc: ""
                keyword_exc: ""

            return feedwind_show_widget_iframe(params, true)


        $('#account_modal').change (e) ->
            $(e.target).parents('.tab-pane').data('dirty', yes)

        $('#get_reset_token').click ->
            username = $("#login_username").val()
            $('#login_modal .alert:visible').hide()

            if not username.length
                $('#login_error').text("Please enter a username to reset the password").slideDown()
                return

    #        $('#login_modal').find('input,a,label,button').slideUp()
            sputnik.getResetToken(username)
            $('#reset_token_sent').show()
            setTimeout(
                ->
                    $('#login_modal .alert:visible').hide()
                    $("#login_modal").modal "hide"
            ,
            5000)

        sputnik.on "change_password_token", (args) ->
            $('#change_password_token_modal').modal "show"

        sputnik.on "change_password_fail", (err) -> #BUG: this is not firing multiple times
            bootbox.alert "Password reset failure: #{err[1]}"

        sputnik.on "change_password_success", (message) ->
            bootbox.alert "Password reset"

        sputnik.on "change_profile_success", (profile) ->
            bootbox.alert "Profile changed"

        sputnik.on "session_expired", ->
            console.log "Session is stale."
            document.cookie = ''

    #    We are disabling chat for now in the UI because we didn't make space for it
    #    sputnik.on "chat_history", (chat_messages) ->
    #        $('#chatArea').html(chat_messages.join("\n"))
    #        $('#chatArea').scrollTop($('#chatArea')[0].scrollHeight)
    #
    #    sputnik.on "chat", (chat) ->
    #        $.growl({title: "Chat", message: chat})

        sputnik.on "address_fail", (error) ->
            bootbox.alert "Deposit address error: #{error[1]}"

        sputnik.on "address", (address) =>
            $('#qr_code').empty()
            if address[0] == "BTC"
                $('#qr_code').qrcode("bitcoin:" + address[1])

        sputnik.on "password_change_success", (info) ->
            bootbox.alert "Password successfully changed"

        sputnik.on "password_change_fail", (error) ->
            bootbox.alert "Password change fail: #{error}"

        sputnik.on "request_withdrawal_success", (info) ->
            bootbox.alert "Withdrawal request placed"

        sputnik.on "request_withdrawal_fail", (error) ->
            bootbox.alert "Withdrawal request failed: #{error[1]}"

        sputnik.on "place_order_fail", (error) ->
            bootbox.alert "order placement failed: #{error[1]}"

        sputnik.on "fill", (fill) ->
            quantity_fmt = fill.quantity.toFixed(sputnik.getQuantityPrecision(fill.contract))
            price_fmt = fill.price.toFixed(sputnik.getPricePrecision(fill.contract))
            $.growl.notice { title: "Fill", message: "#{fill.contract}:#{fill.side}:#{quantity_fmt}@#{price_fmt}" }

        sputnik.on "close", (message) ->
            $('#main_page').hide()
            $('#not_connected').show()

        jQuery.fn.serializeObject = ->
            arrayData = @serializeArray()
            objectData = {}
            $.each arrayData, ->
                if @value?
                    value = @value
                else
                    value = ''
                if objectData[@name]?
                    unless objectData[@name].push
                        objectData[@name] = [objectData[@name]]
                    objectData[@name].push value
                else
                    objectData[@name] = value
            return objectData

        @compliance_client_handler = (form) ->
            fd = new FormData()
            fd.append('username', ractive.get("sputnik.username"))
            passports = form.find('input[name=passport]')[0].files
            residencies = form.find('input[name=residency]')[0].files

            if not passports.length
              bootbox.alert "Must submit a scanned passport"
              return
            if not residencies.length
              bootbox.alert "Must submit a proof of residency"
              return

            fd.append('file', passports[0])
            fd.append('file', residencies[0])
            fd.append('data', JSON.stringify(form.serializeObject()))

            sputnik.getRequestSupportNonce 'Compliance', (nonce) ->
                fd.append('nonce', nonce)

                $.ajax
                    url: "#{location.origin}/ticket_server/create_kyc_ticket",
                    data: fd,
                    processData: false,
                    contentType: false,
                    type: 'POST',
                    success: (data) ->
                        bootbox.alert("Successfully saved:" + data)
                    error: (err) ->
                        bootbox.alert("Error while saving:" + err)
                        sputnik.log ["Error:", err]

        ractive.set "feedwind", getFeedwind()

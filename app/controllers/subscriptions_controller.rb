class SubscriptionsController < ApplicationController
	skip_before_action :verify_authenticity_token
	
	def new
	end

	def create
		Rails.logger.info "=== params: #{params.inspect} ==="
		create_stripe_plan
	end

	def create_stripe_plan
		subscription = Stripe::Plan.create(
      :amount => (params[:amount].to_i)*100,
      :interval => params[:interval],
      :name => params[:name],
      :currency => 'usd',
      :trial_plan => nil,
      :id => SecureRandom.uuid # This ensures that the plan is unique in stripe
    )
    #Save the response to your DB
    flash[:notice] = "Plan successfully created"

  end

	def plans
	  @stripe_list = Stripe::Plan.all
	  @plans = @stripe_list[:data]
	end
  
  # This is the callback from stripe
	def subscription_checkout
	  plan_id = params[:plan_id]
	  plan = Stripe::Plan.retrieve(plan_id)
	  #This should be created on signup.
	  customer = Stripe::Customer.create(
	          :description => "Customer for test@example.com",
	          :source => params[:stripeToken],
	          :email => params[:stripeEmail]
	        )
	  # Save this in your DB and associate with the user;s email
	  stripe_subscription = customer.subscriptions.create(:plan => plan.id)

	  flash[:notice] = "Successfully created a charge"
	  redirect_to '/plans'
	end

	# controllers/subscription_controller.rb
	# Method responsbile for handling stripe webhooks
	# reference https://stripe.com/docs/webhooks
	def webhook
	  begin
	    event_json = JSON.parse(request.body.read)
	    event_object = event_json['data']['object']
	    #refer event types here https://stripe.com/docs/api#event_types
	    case event_json['type']
	      when 'invoice.payment_succeeded'
	        handle_success_invoice event_object
	      when 'invoice.payment_failed'
	        handle_failure_invoice event_object
	      when 'charge.failed'
	        handle_failure_charge event_object
	      when 'customer.subscription.deleted'
	      when 'customer.subscription.updated'
	    end
	  rescue Exception => ex
	    render :json => {:status => 422, :error => "Webhook call failed"}
	    return
	  end
	  render :json => {:status => 200}
	end

	def create_stripe_account_with_bank_info
		acct = Stripe::Account.create(
		  {
		    :type => 'custom',
		    :country => 'US',
		    :email => params[:stripeEmail]
		  }
		)

		acct.external_account = 
		{
		  :object => 'bank_account',
		  :country => 'US',
		  :currency => 'usd',
		  :routing_number => '110000000',
		  :account_number => '000123456789',
		}

		acct.save
		p "saved"

		acct2 = Stripe::Account.retrieve(acct.id)
		p acct2
	end

	def destination_and_customer_charge_mode(source_token_visa, destination_account, total_amount, fee, customer_id, customer_email)
		#Customer create
	  customer = Stripe::Customer.create(
	    email: customer_email,
	    source: source_token_visa
	  )
	  customer_id = customer.id
    # Make paymemt from client to rebel.
    charge_to_rebel = Stripe::Charge.create(
      customer: customer_id,
      amount: total_amount,
      description: "Test1.",
      currency: 'usd',
      destination: {
        account: destination_account,
        amount: total_amount - fee
      }
    )
    Rails.logger.info "=== charge_to_rebel: #{charge_to_rebel.inspect} ==="
		rescue Stripe::CardError => e
		  flash[:error] = e.message
		  redirect_to new_charge_path
	end

	def destination_charge_mode(source_token_visa, destination_account, total_amount, fee)
		charge = Stripe::Charge.create({
		  :amount => total_amount,
		  :currency => "usd",
		  :source => source_token_visa,
		  :destination => {
		    :amount => total_amount - fee,
		    :account => destination_account,
		  }
		})

		rescue Stripe::CardError => e
		  flash[:error] = e.message
		  redirect_to new_charge_path
	end

	def customer_transfer_and_payout_mode()
		#Customer create
	  customer = Stripe::Customer.create(
	    email: params[:stripeEmail],
	    source: params[:stripeToken]
	  )

	  customer_id = customer.id
    # Make paymemt from client to rebel.
    # charge_to_rebel = Stripe::Charge.create(
    #   customer: customer_id,
    #   amount: total_price,
    #   description: "Test.",
    #   currency: 'usd',
    #   destination: {
    #     account: "acct_1BaGNkBduFifQJag",
    #     amount: price_for_rebel
    #   }
    # )
    # Rails.logger.info "=== charge_to_rebel: #{charge_to_rebel.inspect} ==="

	  charge_to_rebel = Stripe::Charge.create(
	    customer: customer.id,
	    amount: total_price,
	    description: 'Rails Stripe customer',
	    currency: 'usd'
	  )
    Rails.logger.info "=== charge_to_rebel: #{charge_to_rebel.inspect} ==="

   	balance_txn = Stripe::Balance.retrieve(
		  {:stripe_account => "acct_1BaGNkBduFifQJag"}
		)
		Rails.logger.info "=== balance_txn: #{balance_txn.inspect} ==="
		# balance_txn = Stripe::Balance.retrieve(charge_to_rebel.balance_transaction)

	  Stripe::Payout.create({
		  :amount => 10000,
		  :currency => "usd",
		}, {:stripe_account => "acct_1BaGNkBduFifQJag"})


    balance_currency = balance_txn.available[0].currency.upcase

	  # Make transer to rebel
	  # Create a Transfer to a connected account (later):
    transfer = Stripe::Transfer.create({
      :amount => price_for_rebel,
      :currency => balance_currency,
      :destination => "acct_1BaGNkBduFifQJag",
      :source_transaction => charge_to_rebel.id,
      :transfer_group => charge_to_rebel.transfer_group,
    })
    Rails.logger.info "=== transfer: #{transfer.inspect} ==="

		rescue Stripe::CardError => e
		  flash[:error] = e.message
		  redirect_to new_charge_path

	end

end

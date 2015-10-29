#encoding:utf-8
require 'axlsx'

class Patch::MembersController < ApplicationController
	
	before_filter :authorize_user!
	# layout 'standard'
	layout "patch"

	before_filter do
		clear_breadcrumbs
		add_breadcrumb("我的佐康",:member_path)
	end

  def new
  end

  def create
     # params[:ecstore_user].merge!(:bank_info=>params[:bank_info].to_s) if params[:bank_info]

      #params[:ecstore_user].merge!(params[:date]) if params[:date]
      
    if @user.update_attributes(params[:user])

#        sql = "insert mdk.sdb_b2c_orders (order_id,total_amount,final_amount,createtime,last_modified,payment,member_id)
# values(20151023135386,10000,10000,1445578550,1445578550,'wxpay');"
#        results = ActiveRecord::Base.connection.execute(sql)

        #删除购物车/加入购物车买卡/生成订单/显示支付方式

         # redirect_to profile_path(:tab=>params[:tab]), :notice=>"保存成功."

      rel_id = "#{Time.now.strftime('%Y%m%d%H%M%S')}"
      installment =  1
      part_pay =  0

      pay_app_id = 'wxpay'    
      pay_amount = 10000
      currency = 'CNY'

    
    # params[:payment].merge! Ecstore::Payment::PAYMENTS[pay_app_id.to_sym]

    @payment = Ecstore::Payment.new  do |payment|     
      payment.payment_id = Ecstore::Payment.generate_payment_id
      payment.memo = "会员卡购买"
      payment.pay_app_id = pay_app_id
      payment.status = 'ready'
      payment.pay_ver = '1.0'
      payment.paycost = 0

      payment.account = 'baohengboi | 佐康自然生态食品'
      payment.member_id = payment.op_id = @user.member_id
      payment.pay_account = @user.login_name
      payment.ip = request.remote_ip

      payment.t_begin = payment.t_confirm = Time.now.to_i
      
      payment.pay_bill = Ecstore::Bill.new do |bill|
        bill.rel_id  = rel_id
        bill.bill_type = "refunds"
        bill.pay_object  = "prepaid_recharge"
        bill.money = pay_amount
      end
    end

    @payment.money = @payment.cur_money = pay_amount
    if @payment.save     
        redirect_to "/payments/pay?id=#{@payment.payment_id}"  #pay_payment_path(@payment.payment_id)
    else
      redirect_to "/member/new"
    end
      
    else
          render "/member/new"
    end
  end

	def show
		@orders = @user.orders.limit(5)
		@unpay_count = @user.orders.where(:pay_status=>'0',:status=>'active').size
		add_breadcrumb("我的佐康原生态食品")
	end

	def orders
		@orders = @user.orders.paginate(:page=>params[:page],:per_page=>10)
		add_breadcrumb("我的订单")
	end

  def shares
    @orders =Ecstore::Order.where(:discount_code=>@user.discount_code).paginate(:page=>params[:page],:per_page=>10)
    add_breadcrumb("我的返利")
  end

	def coupons
		@user_coupons = @user.user_coupons.paginate(:page=>params[:page],:per_page=>10)
		add_breadcrumb("我的优惠券")
  end


  def goods
    @orders = @user.orders.joins(:order_items).where('sdb_b2c_order_items.storaged is null').paginate(:page=>params[:page],:per_page=>10)
    add_breadcrumb("我的商品")
  end

  def inventorys
    @inventorys = @user.inventorys.paginate(:page=>params[:page],:per_page=>10)
    add_breadcrumb("我的库存")
  end

  def inventorylog
    @inventorylog = @user.inventory_log.order("createtime desc").paginate(:page=>params[:page],:per_page=>10)
    add_breadcrumb("出入库记录")
  end

  def export_inventory
    #以后会加入时间区段限制条件
    conditions = { :member_id=>current_account }
    inventorylog = Ecstore::InventoryLog.where(conditions)
    package = Axlsx::Package.new
    workbook = package.workbook
    workbook.styles do |s|
      head_cell = s.add_style  :b=>true, :sz => 10, :alignment => { :horizontal => :center,
                                                                    :vertical => :center}
      product_cell =  s.add_style  :sz => 9, :alignment => {:vertical => :top}

      workbook.add_worksheet(:name => 'Product') do |sheet|

        sheet.add_row ['出/入库','产品编号','条形码','图片','商品名称','价格' ,'出入库数量', '出入库时间'] ,:style=>head_cell

        row_count=0

        inventorylog.each do |log|

          in_or_out =log.in_or_out== "\1"  ? '入库' : '出库'
          createtime =Time.at(log.createtime).to_s
#log.quantity.to_s,log.product_id.quantity.to_s,
          sheet.add_row [in_or_out,log.bn,log.barcode.to_s,nil,log.name,log.price,log.quantity,createtime] ,
                        :style=>product_cell,:height=>50

          row_count +=1

          filename="/home/trade/pics#{log.good.medium_pic}"
          if not FileTest::exist?(filename)
            filename = "#{Rails.root}/app/assets/images/gray_bg.png"
          end
          img = File.expand_path(filename)
          sheet.add_image(:image_src => img, :noSelect => true, :noMove => true) do |image|
            image.width=50
            image.height=80
            image.start_at 3,  row_count
          end

          sheet.column_widths nil, nil,nil,10
        end
      end
    end

    send_data package.to_stream.read,:filename=>"inventory_#{Time.now.strftime('%Y%m%d%H%M%S')}.xlsx"
  end

	def advance
		@advances = @user.member_advances.paginate(:page=>params[:page],:per_page=>10)
		add_breadcrumb("我的预存款")
	end
	
	def favorites
		@favorites = @user.favorites.includes(:good).paginate(:page=>params[:page],:per_page=>10,:order=>"create_time desc")
		add_breadcrumb("我的收藏")
	end
	
end

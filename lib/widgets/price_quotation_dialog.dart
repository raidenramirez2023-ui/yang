import 'package:flutter/material.dart';

import 'package:yang_chow/utils/app_theme.dart';

import 'package:yang_chow/utils/responsive_utils.dart';

import 'package:yang_chow/services/pricing_service.dart';

import 'package:yang_chow/services/reservation_service.dart';

import 'package:yang_chow/services/menu_service.dart';



class PriceQuotationDialog extends StatefulWidget {

  final Map<String, dynamic> reservation;



  const PriceQuotationDialog({

    super.key,

    required this.reservation,

  });



  @override

  State<PriceQuotationDialog> createState() => _PriceQuotationDialogState();

}



class _PriceQuotationDialogState extends State<PriceQuotationDialog> {

  final PricingService _pricingService = PricingService();

  final ReservationService _reservationService = ReservationService();

  

  final _priceController = TextEditingController();

  final _notesController = TextEditingController();

  

  bool _isLoading = false;

  bool _useCustomPrice = true;

  double _suggestedPrice = 0.0;

  Map<String, dynamic>? _pricingBreakdown;

  

  @override

  void initState() {

    super.initState();

    _calculateSuggestedPrice();

  }



  @override

  void dispose() {

    _priceController.dispose();

    _notesController.dispose();

    super.dispose();

  }



  void _calculateSuggestedPrice() {
    // Calculate total from menu items
    double menuTotal = 0.0;
    if (widget.reservation['selected_menu_items'] != null) {
      final items = widget.reservation['selected_menu_items'] as Map<String, dynamic>;
      items.forEach((menuName, quantity) {
        final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
        if (qty > 0) {
          final price = _getMenuItemPrice(menuName);
          if (price != null) {
            menuTotal += price * qty;
          }
        }
      });
    }

    if (menuTotal > 0) {
      _suggestedPrice = menuTotal;
      _pricingBreakdown = {
        'totalPrice': menuTotal,
      };
      _priceController.text = _suggestedPrice.toStringAsFixed(2);
    }

    setState(() {});
  }



  double get _currentPrice {

    try {

      return double.parse(_priceController.text);

    } catch (e) {

      return 0.0;

    }

  }



  double get _currentDeposit {

    return _pricingService.calculateDepositAmount(_currentPrice);

  }



  bool get _isPriceValid {

    if (_useCustomPrice) {

      return _currentPrice > 0; // Only check if price is greater than 0 for custom price

    }

    

    return _currentPrice > 0 && 

           _pricingService.isPriceReasonable(

             durationHours: widget.reservation['duration_hours'] as int? ?? 0,

             numberOfGuests: widget.reservation['number_of_guests'] as int? ?? 0,

             price: _currentPrice,

           );

  }



  String? _getPriceValidationError() {

    // When using custom price, only validate that the price is greater than 0

    if (_useCustomPrice) {

      if (_currentPrice <= 0) return 'Price must be greater than 0';

      return null; // Skip all other validations for custom price

    }

    

    // For suggested price, use full validation

    final validation = _pricingService.validatePricingParams(

      durationHours: widget.reservation['duration_hours'] as int? ?? 0,

      numberOfGuests: widget.reservation['number_of_guests'] as int? ?? 0,

      customBaseRate: null,

    );

    

    if (validation != null) return validation;

    

    if (_currentPrice <= 0) return 'Price must be greater than 0';

    

    if (!_pricingService.isPriceReasonable(

      durationHours: widget.reservation['duration_hours'] as int? ?? 0,

      numberOfGuests: widget.reservation['number_of_guests'] as int? ?? 0,

      price: _currentPrice,

    )) {

      return 'Price seems unreasonable. Please check the amount.';

    }

    

    return null;

  }



  Future<void> _sendQuotation() async {

    if (!_isPriceValid) {

      _showError('Please enter a valid price');

      return;

    }



    setState(() => _isLoading = true);



    try {

      await _reservationService.setReservationPricing(

        reservationId: widget.reservation['id'],

        totalPrice: _currentPrice,

        depositAmount: _currentDeposit,

        customerEmail: widget.reservation['customer_email'],

        customerName: widget.reservation['customer_name'],

        eventType: widget.reservation['event_type'],

        eventDate: widget.reservation['event_date'],

        startTime: widget.reservation['start_time'],

        durationHours: widget.reservation['duration_hours'],

        numberOfGuests: widget.reservation['number_of_guests'],

      );



      if (mounted) {

        Navigator.pop(context, true);

        _showSuccess('Price quotation sent successfully!');

      }

    } catch (e) {

      _showError('Failed to send quotation: $e');

    } finally {

      setState(() => _isLoading = false);

    }

  }



  void _showSuccess(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Row(

          children: [

            Icon(Icons.check_circle, color: Colors.white),

            SizedBox(width: 12),

            Expanded(child: Text(message)),

          ],

        ),

        backgroundColor: Colors.green,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

        margin: EdgeInsets.all(16),

      ),

    );

  }



  void _showError(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Row(

          children: [

            Icon(Icons.error_outline, color: Colors.white),

            SizedBox(width: 12),

            Expanded(child: Text(message)),

          ],

        ),

        backgroundColor: Colors.red,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

        margin: EdgeInsets.all(16),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final isMobile = ResponsiveUtils.isMobile(context);

    

    return Dialog(

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: Container(

        constraints: BoxConstraints(

          maxWidth: isMobile ? double.infinity : 600,

          maxHeight: isMobile ? double.infinity : 800,

        ),

        child: SingleChildScrollView(

          padding: EdgeInsets.all(isMobile ? 16 : 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              // Header

              Row(

                children: [

                  Container(

                    padding: EdgeInsets.all(8),

                    decoration: BoxDecoration(

                      color: AppTheme.primaryColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: Icon(Icons.monetization_on, color: AppTheme.primaryColor),

                  ),

                  SizedBox(width: 12),

                  Expanded(

                    child: Text(

                      'Send Price Quotation',

                      style: TextStyle(

                        fontSize: ResponsiveUtils.getResponsiveFontSize(

                          context,

                          mobile: 18,

                          tablet: 20,

                          desktop: 22,

                        ),

                        fontWeight: FontWeight.bold,

                        color: AppTheme.darkGrey,

                      ),

                    ),

                  ),

                  IconButton(

                    onPressed: () => Navigator.pop(context),

                    icon: Icon(Icons.close),

                  ),

                ],

              ),

              

              SizedBox(height: 24),

              

              // Reservation Details

              _buildReservationDetails(),

              

              SizedBox(height: 24),

              

              // Pricing Options

              _buildPricingOptions(),

              

              SizedBox(height: 24),

              

              // Price Breakdown

              if (_pricingBreakdown != null) _buildPriceBreakdown(),

              

              SizedBox(height: 24),

              

              // Custom Notes

              _buildCustomNotes(),

              

              SizedBox(height: 32),

              

              // Action Buttons

              _buildActionButtons(),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildReservationDetails() {

    return Container(

      padding: EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: AppTheme.lightGrey.withValues(alpha: 0.3),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'Reservation Details',

            style: TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.bold,

              color: AppTheme.darkGrey,

            ),

          ),

          SizedBox(height: 12),

          _buildDetailRow('Customer', widget.reservation['customer_name']),

          _buildDetailRow('Event Type', widget.reservation['event_type']),

          _buildDetailRow('Date', widget.reservation['event_date']),

          _buildDetailRow('Time', widget.reservation['start_time']),

          _buildDetailRow('Duration', '${widget.reservation['duration_hours']} hours'),

          _buildDetailRow('Guests', '${widget.reservation['number_of_guests']} people'),

          // Menu Items (if available)
          if (widget.reservation['selected_menu_items'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Menu Items:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGrey,
              ),
            ),
            SizedBox(height: 4),
            ..._buildMenuItemsList(widget.reservation['selected_menu_items']),
          ],

        ],

      ),

    );

  }



  Widget _buildDetailRow(String label, String value) {

    return Padding(

      padding: EdgeInsets.only(bottom: 8),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 80,

            child: Text(

              '$label:',

              style: TextStyle(

                fontWeight: FontWeight.w600,

                color: AppTheme.mediumGrey,

              ),

            ),

          ),

          Expanded(

            child: Text(

              value,

              style: TextStyle(color: AppTheme.darkGrey),

            ),

          ),

        ],

      ),

    );

  }



  double? _getMenuItemPrice(String menuName) {
    final menu = MenuService.getMenu();
    for (var category in menu.values) {
      for (var item in category) {
        if (item.name == menuName) {
          return item.price;
        }
      }
    }
    return null;
  }

  List<Widget> _buildMenuItemsList(Map<String, dynamic> selectedMenuItems) {
    if (selectedMenuItems.isEmpty) {
      return [
        Text(
          'No menu items selected',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    final menuItems = <Widget>[];
    final items = selectedMenuItems;
    double grandTotal = 0.0;
    
    items.forEach((menuName, quantity) {
      final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
      if (qty > 0) {
        final price = _getMenuItemPrice(menuName);
        final totalPrice = price != null ? price * qty : 0.0;
        grandTotal += totalPrice;
        
        menuItems.add(
          Padding(
            padding: EdgeInsets.only(bottom: 8, left: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuName,
                  style: TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (price != null)
                  Text(
                    '₱${price.toStringAsFixed(2)}   x$qty  =  ₱${totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppTheme.darkGrey,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    });

    // Add grand total separator and amount
    if (grandTotal > 0) {
      menuItems.add(
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4, left: 80),
          child: Divider(),
        ),
      );
      menuItems.add(
        Padding(
          padding: EdgeInsets.only(bottom: 4, left: 80),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Order Amount:',
                style: TextStyle(
                  color: AppTheme.darkGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₱${grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return menuItems;
  }



  Widget _buildPricingOptions() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          'Pricing Options',

          style: TextStyle(

            fontSize: 16,

            fontWeight: FontWeight.bold,

            color: AppTheme.darkGrey,

          ),

        ),

        SizedBox(height: 12),
        
        // Custom Price Option

        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Reservation Price',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Enter the total price for this reservation',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
        ),

        

          SizedBox(height: 8),

          TextField(

            controller: _priceController,

            keyboardType: TextInputType.numberWithOptions(decimal: true),

            decoration: InputDecoration(

              labelText: 'Total Price (PHP)',

              prefixText: 'PHP ',

              border: OutlineInputBorder(),

              errorText: _getPriceValidationError(),

            ),

            onChanged: (value) => setState(() {}),

          ),

          SizedBox(height: 8),

          Text(

            'Deposit will be automatically calculated (50% of total price)',

            style: TextStyle(

              fontSize: 12,

              color: AppTheme.mediumGrey,

            ),

          ),

        ],

    );

  }



  Widget _buildPriceBreakdown() {

    if (_pricingBreakdown == null) return SizedBox.shrink();

    final currentPrice = _currentPrice;
    final currentDeposit = _pricingService.calculateDepositAmount(currentPrice);

    return Container(

      padding: EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: AppTheme.primaryColor.withValues(alpha: 0.05),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            'Price Breakdown',

            style: TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.bold,

              color: AppTheme.darkGrey,

            ),

          ),

          SizedBox(height: 12),

          _buildBreakdownRow(

            'Total Price',

            'PHP ${currentPrice.toStringAsFixed(2)}',

            isBold: true,

          ),

          _buildBreakdownRow(

            'Required Deposit (50%)',

            'PHP ${currentDeposit.toStringAsFixed(2)}',

            color: Colors.green,

          ),

          _buildBreakdownRow(

            'Remaining Balance',

            'PHP ${(currentPrice - currentDeposit).toStringAsFixed(2)}',

            color: AppTheme.mediumGrey,

          ),

        ],

      ),

    );

  }



  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? color}) {

    return Padding(

      padding: EdgeInsets.only(bottom: 4),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(

            label,

            style: TextStyle(

              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,

              color: color ?? AppTheme.darkGrey,

            ),

          ),

          Text(

            value,

            style: TextStyle(

              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,

              color: color ?? AppTheme.darkGrey,

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildCustomNotes() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          'Additional Notes (Optional)',

          style: TextStyle(

            fontSize: 16,

            fontWeight: FontWeight.bold,

            color: AppTheme.darkGrey,

          ),

        ),

        SizedBox(height: 8),

        TextField(

          controller: _notesController,

          maxLines: 3,

          decoration: InputDecoration(

            hintText: 'Add any special notes for the customer...',

            border: OutlineInputBorder(),

          ),

        ),

      ],

    );

  }



  Widget _buildActionButtons() {

    return Row(

      children: [

        Expanded(

          child: OutlinedButton(

            onPressed: () => Navigator.pop(context),

            style: OutlinedButton.styleFrom(

              padding: EdgeInsets.symmetric(vertical: 16),

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            ),

            child: Text('Cancel'),

          ),

        ),

        SizedBox(width: 16),

        Expanded(

          child: ElevatedButton(

            onPressed: _isLoading ? null : _sendQuotation,

            style: ElevatedButton.styleFrom(

              backgroundColor: AppTheme.primaryColor,

              foregroundColor: Colors.white,

              padding: EdgeInsets.symmetric(vertical: 16),

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            ),

            child: _isLoading

                ? Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      SizedBox(

                        width: 16,

                        height: 16,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          valueColor: AlwaysStoppedAnimation(Colors.white),

                        ),

                      ),

                      SizedBox(width: 8),

                      Text('Sending...'),

                    ],

                  )

                : Text('Send Quotation'),

          ),

        ),

      ],

    );

  }

}


" local handler class
CLASS ltc_readonly_methods DEFINITION DEFERRED FOR TESTING.
CLASS ltc_writing_methods DEFINITION DEFERRED FOR TESTING.

CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler
FRIENDS ltc_readonly_methods ltc_writing_methods.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        accepted TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected TYPE c LENGTH 1 VALUE 'X', "Rejected
      END OF travel_status.

    METHODS get_instance_features       FOR INSTANCE FEATURES IMPORTING keys REQUEST requested_features FOR Travel RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS earlynumbering_create      FOR NUMBERING IMPORTING entities FOR CREATE Travel.
    METHODS earlynumbering_cba_Booking FOR NUMBERING IMPORTING entities FOR CREATE Travel\_Booking.

    METHODS acceptTravel     FOR MODIFY IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.
    METHODS rejectTravel     FOR MODIFY IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.
    METHODS reCalcTotalPrice FOR MODIFY IMPORTING keys FOR ACTION Travel~reCalcTotalPrice.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~calculateTotalPrice.
    METHODS setStatusToOpen     FOR DETERMINE ON MODIFY IMPORTING keys FOR Travel~setStatusToOpen.
    METHODS validateAgency      FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateAgency.

    METHODS validateCustomer FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateCustomer.
    METHODS validateDates    FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateDates.
    METHODS validateStatus   FOR VALIDATE ON SAVE IMPORTING keys FOR Travel~validateStatus.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

********************************************************************************
* Implements the dynamic feature control handling for travel instances
********************************************************************************
  METHOD get_instance_features.
    "read entities
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
         FIELDS (  TravelID OverallStatus )
         WITH CORRESPONDING #( keys )
       RESULT DATA(lt_travel)
       FAILED failed.

    " set the appropriate state according to relevant condition evaluation
    result = VALUE #( FOR ls_travel IN lt_travel
                       ( %key                           = ls_travel-%key
                         %features-%action-rejecttravel = COND #( WHEN ls_travel-OverallStatus = 'X'
                                                                    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled  )
                         %features-%action-accepttravel = COND #( WHEN ls_travel-OverallStatus = 'A'
                                                                    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                         %assoc-_booking                = COND #( WHEN ls_travel-OverallStatus = 'X'
                                                                    THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                      ) ).
  ENDMETHOD.

********************************************************************************
* Instance-based authorization
********************************************************************************
  METHOD get_instance_authorizations.
    "no implementation provided
  ENDMETHOD.

**********************************************************************
* Early numbering of new travel instances using number ranges
**********************************************************************
  METHOD earlyNumbering_create.

***********************************************************************************************
*   In this hands-on session we simplify this with a select max(travel_id)                    *
*   Please note that the numbering exit should use a number range object in a real scenario   *
***********************************************************************************************

    " Mapping for already assigned travel IDs (e.g. during draft activation)
    mapped-travel = VALUE #( FOR entity IN entities WHERE ( TravelID IS NOT INITIAL )
                                                          ( %cid      = entity-%cid
                                                            %key      = entity-%key ) ).

    " This should be a number range. But for the demo purpose, avoiding the need to configure this in each and every system, we select the max value ...
    SELECT MAX( travel_id ) FROM zrap400_travssc INTO @DATA(max_travel_id).

    " Mapping for newly assigned travel IDs
    mapped-travel = VALUE #( BASE mapped-travel FOR entity IN entities INDEX INTO i
                                                    USING KEY entity
                                                    WHERE ( TravelID IS INITIAL )
                                                          ( %cid      = entity-%cid
                                                            TravelID  = max_travel_id + i ) ).

  ENDMETHOD.

**********************************************************************
* Early numbering of new booking instances
**********************************************************************
  METHOD earlyNumbering_cba_Booking.

    DATA: max_booking_id TYPE /dmo/booking_id.

    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY travel BY \_booking
        FIELDS ( BookingID )
          WITH CORRESPONDING #( entities )
          RESULT DATA(bookings)
          FAILED failed.

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<booking>).
      " Get highest booking_id from bookings belonging to travel
      max_booking_id = REDUCE #( INIT max = CONV /dmo/booking_id( '0' )
                                       FOR  booking IN bookings USING KEY entity
                                                                             WHERE ( TravelID  = <booking>-TravelID )
                                       NEXT max = COND /dmo/booking_id(      WHEN booking-BookingID > max
                                                                             THEN booking-BookingID
                                                                             ELSE max )
                                     ).

      " map booking which already have an id (required for draft)
      LOOP AT <booking>-%target INTO DATA(booking_w_numbers) WHERE BookingID IS NOT INITIAL.
        APPEND CORRESPONDING #( booking_w_numbers ) TO mapped-booking.
      ENDLOOP.

      "assign new booking-ids
      LOOP AT <booking>-%target INTO DATA(booking_wo_numbers) WHERE BookingID IS INITIAL.
        APPEND CORRESPONDING #( booking_wo_numbers ) TO mapped-booking ASSIGNING FIELD-SYMBOL(<mapped_booking>).
        max_booking_id += 10 .
        <mapped_booking>-BookingID = max_booking_id.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

*********************************************************************
* Set the overall travel status to 'accepted'
**********************************************************************
  METHOD acceptTravel.
    " modify travel instance
    MODIFY ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky           = key-%tky
                                        OverallStatus = travel_status-accepted ) )  " 'A'
    FAILED failed
    REPORTED reported.

    " read changed data for action result
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH
        CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels ( %tky   = travel-%tky
                                              %param = travel ) ).
  ENDMETHOD.

**********************************************************************
* Set the overall travel status to 'rejected'
**********************************************************************
  METHOD rejectTravel.
    " modify travel instance
    MODIFY ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky           = key-%tky
                                        OverallStatus = travel_status-rejected ) )  " 'X'
    FAILED failed
    REPORTED reported.

    " read changed data for action result
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH
        CORRESPONDING #( keys )
      RESULT DATA(lt_travel).

    result = VALUE #( FOR ls_travel IN lt_travel ( %tky   = ls_travel-%tky
                                                   %param = ls_travel ) ).
  ENDMETHOD.

**********************************************************************
* Internal action: Calculate the total price of a travel
* (Booking fees + Booking prices + booking supplement prices)
**********************************************************************
  METHOD reCalcTotalPrice.

    TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: amount_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    " Read all relevant travel instances.
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
         ENTITY travel
            FIELDS ( BookingFee CurrencyCode )
            WITH CORRESPONDING #( keys )
         RESULT DATA(lt_travel)
         FAILED failed.

    DELETE lt_travel WHERE CurrencyCode IS INITIAL.

    LOOP AT lt_travel ASSIGNING FIELD-SYMBOL(<fs_travel>).
      " Set the start for the calculation by adding the booking fee.
      amount_per_currencycode = VALUE #( ( amount        = <fs_travel>-BookingFee
                                           currency_code = <fs_travel>-CurrencyCode ) ).

      " Read all associated bookings and add them to the total price.
      READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
        ENTITY travel BY \_booking
          FIELDS ( FlightPrice CurrencyCode )
        WITH VALUE #( ( %key = <fs_travel>-%key ) )
        RESULT DATA(lt_booking).

      LOOP AT lt_booking INTO DATA(booking) WHERE CurrencyCode IS NOT INITIAL.
        COLLECT VALUE ty_amount_per_currencycode( amount        = booking-FlightPrice
                                                  currency_code = booking-CurrencyCode ) INTO amount_per_currencycode.
      ENDLOOP.

      CLEAR <fs_travel>-TotalPrice.
      LOOP AT amount_per_currencycode INTO DATA(single_amount_per_currencycode).
        " if needed, do a currency conversion
        IF single_amount_per_currencycode-currency_code = <fs_travel>-CurrencyCode.
          <fs_travel>-TotalPrice += single_amount_per_currencycode-amount.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
             EXPORTING
               iv_amount                   =  single_amount_per_currencycode-amount
               iv_currency_code_source     =  single_amount_per_currencycode-currency_code
               iv_currency_code_target     =  <fs_travel>-CurrencyCode
               iv_exchange_rate_date       =  cl_abap_context_info=>get_system_date( )
             IMPORTING
               ev_amount                   = DATA(total_booking_price_per_curr)
            ).
          <fs_travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " write back the modified total_price of travels
    MODIFY ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        UPDATE FIELDS ( TotalPrice )
        WITH CORRESPONDING #( lt_travel ).
  ENDMETHOD.

**********************************************************************
* Calculate the total price of a travel
* (Booking fee + Booking flight prices )
**********************************************************************
  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        EXECUTE recalctotalprice
        FROM CORRESPONDING #( keys )
    REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.

**********************************************************************
* Set the overall travel status to 'open' if empty
**********************************************************************
  METHOD setStatusToOpen.

    " read travel instance(s) of the transferred keys
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
     ENTITY Travel
       FIELDS ( OverallStatus )
       WITH CORRESPONDING #( keys )
     RESULT DATA(travels)
     FAILED DATA(read_failed).

    " if travel status is already set, do nothing
    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.
    " else set travel status to open ('O')
    MODIFY ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY Travel
        UPDATE SET FIELDS
        WITH VALUE #( FOR travel IN travels ( %tky    = travel-%key
                                             OverallStatus = travel_status-open ) )  "'O'
    REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.

**********************************************************************
* Check the validity of the  agency data
**********************************************************************
  METHOD validateAgency.
    " Read relevant travel instance data
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
    ENTITY Travel
     FIELDS ( AgencyID )
     WITH CORRESPONDING #(  keys )
    RESULT DATA(lt_travel).

    DATA lt_agency TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.

    " Optimization of DB select: extract distinct non-initial agency IDs
    lt_agency = CORRESPONDING #(  lt_travel DISCARDING DUPLICATES MAPPING agency_id = AgencyID EXCEPT * ).
    DELETE lt_agency WHERE agency_id IS INITIAL.
    IF  lt_agency IS NOT INITIAL.

      " check if agency ID exist
      SELECT FROM /dmo/agency FIELDS agency_id
        FOR ALL ENTRIES IN @lt_agency
        WHERE agency_id = @lt_agency-agency_id
        INTO TABLE @DATA(lt_agency_db).
    ENDIF.

    " Raise msg for non existing and initial agency id
    LOOP AT lt_travel INTO DATA(ls_travel).
      IF ls_travel-AgencyID IS INITIAL
         OR NOT line_exists( lt_agency_db[ agency_id = ls_travel-AgencyID ] ).
        APPEND VALUE #(  travelID = ls_travel-TravelID ) TO failed-travel.
        APPEND VALUE #(  travelID = ls_travel-TravelID
                         %msg = new_message( id        = '/DMO/CM_FLIGHT_LEGAC'
                                             number    = '001'
                                             v1        = ls_travel-AgencyID
                                             severity  = if_abap_behv_message=>severity-error )
                         %element-AgencyID = if_abap_behv=>mk-on )
          TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

**********************************************************************
* Check the validity of the entered customer data
**********************************************************************
  METHOD validateCustomer.
    " Read relevant travel instance data
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
    ENTITY Travel
     FIELDS ( CustomerID )
     WITH CORRESPONDING #( keys )
    RESULT DATA(lt_travel).

    DATA lt_customer TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    " Optimization of DB select: extract distinct non-initial customer IDs
    lt_customer = CORRESPONDING #( lt_travel DISCARDING DUPLICATES MAPPING customer_id = customerID EXCEPT * ).
    DELETE lt_customer WHERE customer_id IS INITIAL.
    IF lt_customer IS NOT INITIAL.

      " Check if customer ID exists
      SELECT FROM /dmo/customer FIELDS customer_id
        FOR ALL ENTRIES IN @lt_customer
        WHERE customer_id = @lt_customer-customer_id
        INTO TABLE @DATA(lt_customer_db).
    ENDIF.
    " Raise msg for non existing and initial customer id
    LOOP AT lt_travel INTO DATA(ls_travel).
      IF ls_travel-CustomerID IS INITIAL
         OR NOT line_exists( lt_customer_db[ customer_id = ls_travel-CustomerID ] ).

        APPEND VALUE #(  TravelID = ls_travel-TravelID ) TO failed-travel.
        APPEND VALUE #(  TravelID = ls_travel-TravelID
                         %msg = new_message( id        = '/DMO/CM_FLIGHT_LEGAC'
                                             number    = '002'
                                             v1        = ls_travel-CustomerID
                                             severity  = if_abap_behv_message=>severity-error )
                         %element-CustomerID = if_abap_behv=>mk-on )
          TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

**********************************************************************
* Check the validity of begin and end dates
**********************************************************************
  METHOD validateDates.
    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
      ENTITY travel
        FIELDS ( BeginDate EndDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travel_result).

    LOOP AT lt_travel_result INTO DATA(ls_travel_result).

      IF ls_travel_result-EndDate < ls_travel_result-BeginDate.  "end_date before begin_date

        APPEND VALUE #( %key        = ls_travel_result-%key
                        travelID    = ls_travel_result-TravelID ) TO failed-travel.

        APPEND VALUE #( %key = ls_travel_result-%key
                        %msg     = new_message( id       = /dmo/cx_flight_legacy=>end_date_before_begin_date-msgid
                                                number   = /dmo/cx_flight_legacy=>end_date_before_begin_date-msgno
                                                v1       = ls_travel_result-BeginDate
                                                v2       = ls_travel_result-EndDate
                                                v3       = ls_travel_result-TravelID
                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.

      ELSEIF ls_travel_result-BeginDate < cl_abap_context_info=>get_system_date( ).  "begin_date must be in the future

        APPEND VALUE #( %key       = ls_travel_result-%key
                        travelID   = ls_travel_result-TravelID ) TO failed-travel.

        APPEND VALUE #( %key = ls_travel_result-%key
                        %msg = new_message( id       = /dmo/cx_flight_legacy=>begin_date_before_system_date-msgid
                                            number   = /dmo/cx_flight_legacy=>begin_date_before_system_date-msgno
                                            severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

**********************************************************************
* Check the validity the overall travel status
**********************************************************************
  METHOD validateStatus.

    READ ENTITIES OF ZRAP400_i_Travel_SSC IN LOCAL MODE
        ENTITY Travel
          FIELDS ( OverallStatus )
          WITH CORRESPONDING #( keys )
        RESULT DATA(lt_travel_result).

    LOOP AT lt_travel_result INTO DATA(ls_travel_result).
      CASE ls_travel_result-OverallStatus.
        WHEN travel_status-open OR travel_status-rejected OR travel_status-accepted.
*        WHEN 'B'. " booked
        WHEN OTHERS.
          APPEND VALUE #( %key = ls_travel_result-%key ) TO failed-travel.
          APPEND VALUE #( %key = ls_travel_result-%key
                          %msg = new_message( id       = /dmo/cx_flight_legacy=>status_is_not_valid-msgid
                                              number   = /dmo/cx_flight_legacy=>status_is_not_valid-msgno
                                              v1       = ls_travel_result-OverallStatus
                                              severity = if_abap_behv_message=>severity-error )
                          %element-OverallStatus = if_abap_behv=>mk-on ) TO reported-travel.

      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS ltc_helper DEFINITION FOR TESTING CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-DATA:
      mo_client_proxy      TYPE REF TO /iwbep/if_cp_client_proxy,
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment,

      agency_mock_data     TYPE STANDARD TABLE OF /dmo/agency,
      customer_mock_data   TYPE STANDARD TABLE OF /dmo/customer,
      carrier_mock_data    TYPE STANDARD TABLE OF /dmo/carrier,
      flight_mock_data     TYPE STANDARD TABLE OF /dmo/flight,
      travel_mock_data     TYPE STANDARD TABLE OF ZRAP400_TravSSC,
      booking_mock_data    TYPE STANDARD TABLE OF ZRAP400_BookSSC,

      begin_date           TYPE /dmo/begin_date,
      end_date             TYPE /dmo/end_date.

    CLASS-METHODS:
      helper_class_setup RAISING cx_static_check,
      helper_class_teardown,
      helper_setup,
      helper_teardown.
ENDCLASS.

CLASS ltc_helper IMPLEMENTATION.

  METHOD helper_class_setup.

    " create client proxy
    mo_client_proxy = cl_web_odata_client_factory=>create_v2_local_proxy(
                                            VALUE #( service_id      = 'ZRAP400_UI_TRAVEL_SSC_O2'
                                                     service_version = '0001' ) ).
    " create the test doubles for the underlying CDS entities
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
                      i_for_entities = VALUE #(
                        ( i_for_entity = 'ZRAP400_C_Travel_SSC'    i_select_base_dependencies = abap_true )
                        ( i_for_entity = 'ZRAP400_C_BOOKING_SSC'   i_select_base_dependencies = abap_true ) ) ).

    " create the test doubles for referenced and additional used tables.
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( '/DMO/AGENCY' )
                                                                                          ( '/DMO/CUSTOMER' )
                                                                                          ( '/DMO/CARRIER' )
                                                                                          ( '/DMO/FLIGHT' ) ) ).

    " prepare test data
    agency_mock_data   = VALUE #( ( agency_id = '987654' name = 'Agency 987654' ) ).
    customer_mock_data = VALUE #( ( customer_id = '987653' last_name = 'customer 987653' ) ).
    carrier_mock_data  = VALUE #( ( carrier_id = '123' name = 'carrier 123' ) ).
    flight_mock_data   = VALUE #( ( carrier_id = '123' connection_id = '9876' flight_date = begin_date
                                    price = '2000' currency_code = 'EUR' ) ).

    begin_date = cl_abap_context_info=>get_system_date( ) + 10.
    end_date   = cl_abap_context_info=>get_system_date( ) + 30.

    travel_mock_data =  VALUE #( ( travel_id      = '101'
                                   agency_id      = agency_mock_data[ 1 ]-agency_id
                                   customer_id    = customer_mock_data[ 1 ]-customer_id
                                   begin_date     = begin_date
                                   end_date       = end_date
                                   booking_fee    = '20'
                                   currency_code  = 'EUR'
                                   description    = 'Mock Travel'
                                   overall_status = 'O' ) ).

    booking_mock_data = VALUE #( ( travel_id      = '101'
                                   booking_id     = '2001'
                                   customer_id    = customer_mock_data[ 1 ]-customer_id
                                   carrier_id     = flight_mock_data[ 1 ]-carrier_id
                                   connection_id  = flight_mock_data[ 1 ]-connection_id
                                   flight_date    = flight_mock_data[ 1 ]-flight_date
                                   flight_price   = flight_mock_data[ 1 ]-price
                                   currency_code  = flight_mock_data[ 1 ]-currency_code
                                   booking_status = 'N' ) ).


  ENDMETHOD.

  METHOD helper_class_teardown.

    " remove test doubles
    cds_test_environment->destroy(  ).
    sql_test_environment->destroy(  ).
  ENDMETHOD.

  METHOD helper_setup.

    " clear test doubles
    sql_test_environment->clear_doubles(  ).
    cds_test_environment->clear_doubles(  ).
    " insert test data into test doubles
    cds_test_environment->insert_test_data( travel_mock_data   ).
    cds_test_environment->insert_test_data( booking_mock_data  ).

    sql_test_environment->insert_test_data( agency_mock_data   ).
    sql_test_environment->insert_test_data( customer_mock_data ).
    sql_test_environment->insert_test_data( carrier_mock_data  ).
    sql_test_environment->insert_test_data( flight_mock_data   ).

  ENDMETHOD.

  METHOD helper_teardown.

    " clean up any involved entity
    ROLLBACK ENTITIES.

  ENDMETHOD.
ENDCLASS.


"!@testing SRVB:ZRAP400_UI_TRAVEL_SSC
CLASS ltc_CREATE DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,
      create FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_CREATE IMPLEMENTATION.
  METHOD class_setup.
    ltc_helper=>helper_class_setup( ).
  ENDMETHOD.

  METHOD class_teardown.
    ltc_helper=>helper_class_teardown( ).
  ENDMETHOD.

  METHOD setup.
    ltc_helper=>helper_setup( ).
  ENDMETHOD.

  METHOD teardown.
    ltc_helper=>helper_teardown( ).
  ENDMETHOD.

  METHOD create.

    "**********************************************************************
    "* 01) This method tests/calls a simple create operation and
    "*     check if the data is available via EML and in the database
    "**********************************************************************
    " prepare business data, i.e. the travel instance test data
    DATA(ls_business_data) = VALUE ZRAP400_C_Travel_SSC(
           agencyid     = ltc_helper=>agency_mock_data[ 1 ]-agency_id
           customerid   = ltc_helper=>customer_mock_data[  1 ]-customer_id
           begindate    = ltc_helper=>begin_date
           enddate      = ltc_helper=>end_date
           bookingfee   = '10.50'
           currencycode = 'EUR'
           description  = 'TestTravel 1' ).

    " create a request for the create operation
    DATA(lo_request) = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->create_request_for_create( ).

    " set the business data for the created entity
    lo_request->set_business_data( ls_business_data ).

    " execute the request
    DATA(lo_response) = lo_request->execute( ).

    cl_abap_unit_assert=>assert_not_initial( lo_response ).

    DATA ls_response_data TYPE ZRAP400_C_Travel_SSC.
    lo_response->get_business_data( IMPORTING es_business_data = ls_response_data ).

    " assert the description from the response
    cl_abap_unit_assert=>assert_equals( msg = 'description from response'    act = ls_response_data-description   exp = ls_business_data-description ).
    " assert that the overall travel status has been set to 'open' from the response
    cl_abap_unit_assert=>assert_equals( msg = 'overall status from response' act = ls_response_data-OverallStatus exp = 'O'  ).

    " read the created travel entity
    READ ENTITIES OF ZRAP400_C_Travel_SSC
      ENTITY Travel
        FIELDS ( description OverallStatus )
          WITH VALUE #( ( TravelID = ls_response_data-TravelID ) )
        RESULT DATA(lt_read_travel)
        FAILED DATA(failed)
        REPORTED DATA(reported).

    " assert data retrieved via READ ENTITIES
    cl_abap_unit_assert=>assert_initial( msg = 'travel from read' act = failed ).
    cl_abap_unit_assert=>assert_equals( msg = 'description from read'    act = lt_read_travel[ 1 ]-description   exp = ls_business_data-description ).
    " assert that the initial value of overall travel status has been set to 'open'
    cl_abap_unit_assert=>assert_equals( msg = 'overall status from read' act = lt_read_travel[ 1 ]-OverallStatus exp = 'O'  ).

    " assert data also from database
    SELECT * FROM zrap400_travSSC WHERE travel_id = @ls_response_data-TravelID
      INTO TABLE @DATA(lt_travel).
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel from db'    act = lt_travel ).
    cl_abap_unit_assert=>assert_equals( msg = 'description from db'    act = lt_travel[ 1 ]-description    exp = ls_business_data-description ).
    cl_abap_unit_assert=>assert_equals( msg = 'overall status from db' act = lt_travel[ 1 ]-overall_status exp = 'O'  ).

  ENDMETHOD.
ENDCLASS.

"!@testing SRVB:ZRAP400_UI_TRAVEL_SSC_O2
CLASS ltc_DEEP_CREATE DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,
      deep_create FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_DEEP_CREATE IMPLEMENTATION.

  METHOD class_setup.
    ltc_helper=>helper_class_setup( ).
  ENDMETHOD.

  METHOD class_teardown.
    ltc_helper=>helper_class_teardown( ).
  ENDMETHOD.

  METHOD setup.
    ltc_helper=>helper_setup( ).
  ENDMETHOD.

  METHOD teardown.
    ltc_helper=>helper_teardown( ).
  ENDMETHOD.

  METHOD deep_create.

    "**********************************************************************
    "* 02) This method tests/calls a deep create operation and
    "*     check if the data is available via EML and in the database
    "**********************************************************************
    " define deep structure type for travel and booking
    TYPES BEGIN OF ty_travel_and_booking.
    INCLUDE TYPE ZRAP400_C_Travel_SSC.
    TYPES to_booking TYPE STANDARD TABLE OF zrap400_c_booking_SSC WITH DEFAULT KEY.
    TYPES END OF ty_travel_and_booking.
    DATA ls_response_data TYPE ty_travel_and_booking.

    " create request for creating Travel instance
    DATA(lo_request) = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->create_request_for_create( ).

    " add a child node to parent having association relationship
    DATA(lo_data_description_node) = lo_request->create_data_descripton_node( ).
    lo_data_description_node->add_child( 'TO_BOOKING' ). "Prefix 'TO_' required

    " prepare business data i.e. the travel and booking instance test data
    DATA(ls_business_data) = VALUE ty_travel_and_booking(
                                        agencyid        = ltc_helper=>agency_mock_data[ 1 ]-agency_id
                                        customerid      = ltc_helper=>customer_mock_data[ 1 ]-customer_id
                                        begindate       = ltc_helper=>begin_date
                                        enddate         = ltc_helper=>end_date
                                        bookingfee      = '21'
                                        currencycode    = 'USD'
                                        description     = 'TestTravel 2'
                                        "the input data should include the data for the child node set above
                                        to_booking = VALUE #( ( CustomerID    = ltc_helper=>customer_mock_data[ 1 ]-customer_id
                                                                CarrierID     = ltc_helper=>flight_mock_data[ 1 ]-carrier_id
                                                                ConnectionID  = ltc_helper=>flight_mock_data[ 1 ]-connection_id
                                                                FlightDate    = ltc_helper=>flight_mock_data[ 1 ]-flight_date
                                                                FlightPrice   = ltc_helper=>flight_mock_data[ 1 ]-price
                                                                CurrencyCode  = ltc_helper=>flight_mock_data[ 1 ]-currency_code
                                                                BookingStatus = 'N'  ) ) ).

    "set the input: business data and data description
    lo_request->set_deep_business_data(
      EXPORTING
        is_business_data    = ls_business_data
        io_data_description = lo_data_description_node ).

    " execute the request
    DATA(lo_response) = lo_request->execute( ).
    lo_response->get_business_data( IMPORTING es_business_data = ls_response_data ).

    ""Read via EML
    READ ENTITIES OF ZRAP400_C_Travel_SSC
      ENTITY Travel
      FIELDS ( description ) WITH VALUE #( ( travelid = ls_response_data-TravelID ) )
        RESULT DATA(lt_read_travel)
      BY \_Booking
      FIELDS ( CarrierID ) WITH VALUE #( ( travelid = ls_response_data-TravelID ) )
        RESULT DATA(lt_read_booking)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    " assert data from read
    cl_abap_unit_assert=>assert_equals( msg = 'description from read' act = lt_read_travel[ 1 ]-Description  exp = 'TestTravel 2' ).
    cl_abap_unit_assert=>assert_equals( msg = 'carrier-id from read'  act = lt_read_booking[ 1 ]-CarrierID   exp = ltc_helper=>flight_mock_data[ 1 ]-carrier_id ).

    " assert data also from database
    SELECT * FROM zrap400_travSSC WHERE travel_id = @ls_response_data-TravelID
      INTO TABLE @DATA(lt_travel).
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel from db'    act = lt_travel ).
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel-id from db' act = lt_travel[ 1 ]-travel_id ).
    cl_abap_unit_assert=>assert_equals( msg = 'description from read'  act = lt_travel[ 1 ]-Description  exp = 'TestTravel 2' ).

    SELECT * FROM zrap400_bookSSC WHERE travel_id = @ls_response_data-TravelID
      INTO TABLE @DATA(lt_booking).
    cl_abap_unit_assert=>assert_not_initial( msg = 'booking from db'    act = lt_booking ).
    cl_abap_unit_assert=>assert_not_initial( msg = 'booking-id from db' act = lt_booking[ 1 ]-booking_id ).
    cl_abap_unit_assert=>assert_equals( msg = 'carrier-id from read'    act = lt_booking[ 1 ]-carrier_id  exp = ltc_helper=>flight_mock_data[ 1 ]-carrier_id ).

  ENDMETHOD.

ENDCLASS.



"!@testing SRVB:ZRAP400_UI_TRAVEL_SSC_O2
CLASS ltc_READ_LIST DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,
      read_list FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_READ_LIST IMPLEMENTATION.

  METHOD class_setup.
    ltc_helper=>helper_class_setup( ).
  ENDMETHOD.

  METHOD class_teardown.
    ltc_helper=>helper_class_teardown( ).
  ENDMETHOD.

  METHOD setup.
    ltc_helper=>helper_setup( ).
  ENDMETHOD.

  METHOD teardown.
    ltc_helper=>helper_teardown( ).
  ENDMETHOD.

  METHOD read_list.

    "**********************************************************************
    "* 05) This method tests/calls the read_list operation (OData query)
    "* and checks the result
    "**********************************************************************
    DATA: lt_range_agencyid   TYPE RANGE OF /dmo/agency_id,
          lt_range_customerid TYPE RANGE OF /dmo/customer_id,
          lt_business_data    TYPE STANDARD TABLE OF ZRAP400_C_Travel_SSC.
    lt_range_agencyid = VALUE #( ( low    = ltc_helper=>agency_mock_data[ 1 ]-agency_id
                                   option = 'EQ'
                                   sign   = 'I' ) ).

    lt_range_customerid = VALUE #( ( low    = ltc_helper=>customer_mock_data[ 1 ]-customer_id
                                     option = 'EQ'
                                     sign   = 'I' ) ).

    " Navigate to the resource
    DATA(lo_request) = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->create_request_for_read( ).

    " Create the filter tree
    DATA(lo_filter_factory) = lo_request->create_filter_factory( ).
    "
    DATA(lo_filter_node_1)  = lo_filter_factory->create_by_range( iv_property_path = 'AGENCYID'
                                                                  it_range         = lt_range_agencyid ).
    DATA(lo_filter_node_2)  = lo_filter_factory->create_by_range( iv_property_path = 'CUSTOMERID'
                                                                  it_range         = lt_range_customerid ).
    DATA(lo_filter_node_root) = lo_filter_node_1->and( lo_filter_node_2 ).

    lo_request->set_filter( lo_filter_node_root ).

    " Set top & skip
    lo_request->set_top( 50 )->set_skip( 0 ).

    DATA(lo_response) = lo_request->execute( ).
    lo_response->get_business_data( IMPORTING et_business_data = lt_business_data ).

    " assert data also from database
    SELECT * FROM zrap400_travSSC WHERE agency_id   IN @lt_range_agencyid
                                  AND   customer_id IN @lt_range_customerid
      INTO TABLE @DATA(lt_travel).

    cl_abap_unit_assert=>assert_equals( msg = 'query result equal - count'    act = lines( lt_business_data )       exp = lines( lt_travel ) ).
    cl_abap_unit_assert=>assert_equals( msg = 'query result equal - travelid' act = lt_business_data[ 1 ]-TravelID  exp = lt_travel[ 1 ]-travel_id   ).

  ENDMETHOD.


ENDCLASS.

"!@testing SRVB:ZRAP400_UI_TRAVEL_SSC_O2
CLASS ltc_UPDATE DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,
      update FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_UPDATE IMPLEMENTATION.

  METHOD class_setup.
    ltc_helper=>helper_class_setup( ).
  ENDMETHOD.

  METHOD class_teardown.
    ltc_helper=>helper_class_teardown( ).
  ENDMETHOD.

  METHOD setup.
    ltc_helper=>helper_setup( ).
  ENDMETHOD.

  METHOD teardown.
    ltc_helper=>helper_teardown( ).
  ENDMETHOD.

  METHOD update.
    "**********************************************************************
    "* 03) This method tests/calls a simple update operation and
    "*     check if the data is available via EML and in the database
    "**********************************************************************
    TYPES: BEGIN OF  ty_entity_key,
             travelID TYPE /dmo/travel_id,
           END OF ty_entity_key.


    " prepare business data - travel description and booking fees to be updated

    DATA ls_business_data TYPE ZRAP400_C_Travel_SSC.
    ls_business_data-Description = 'Travel updated'.
    ls_business_data-BookingFee  = '31.40'.


    " set entity key
    DATA(ls_entity_key) = VALUE ty_entity_key( travelID = ltc_helper=>travel_mock_data[ 1 ]-travel_id ).


    " navigate to the resource
    DATA(lo_resource) = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->navigate_with_key( ls_entity_key ).


    ""read
    " Execute the request and retrieve the business data
    DATA(lo_response_read) = lo_resource->create_request_for_read( )->execute( ).


    ""update
    " create request for the  update operation
    DATA(lo_request) = lo_resource->create_request_for_update( /iwbep/if_cp_request_update=>gcs_update_semantic-patch ).


    "" ETag is needed
    " set the business data
    lo_request->set_business_data( is_business_data = ls_business_data
    it_provided_property = VALUE #( ( `DESCRIPTION` ) ( `BOOKINGFEE` ) ) ).
    " You need to retrieve ETag and then set it here
    lo_request->set_if_match( lo_response_read->get_etag(  ) ).


    " execute the request and retrieve the business data
    DATA(lo_response) = lo_request->execute( ).
    lo_response->get_business_data( IMPORTING es_business_data = ls_business_data ).


    ""read the updated travel entity
    READ ENTITIES OF ZRAP400_C_Travel_SSC
    ENTITY Travel
    FIELDS ( BookingFee description ) WITH VALUE #( ( travelid = ltc_helper=>travel_mock_data[ 1 ]-travel_id  ) )
    RESULT DATA(lt_read_travel)
    FAILED DATA(failed)
    REPORTED DATA(reported).


    cl_abap_unit_assert=>assert_equals( msg = 'Travel description updated' act = lt_read_travel[ 1 ]-Description exp = 'Travel updated' ).
    cl_abap_unit_assert=>assert_equals( msg = 'Booking fees updated'       act = lt_read_travel[ 1 ]-BookingFee  exp = '31.40'           ).

  ENDMETHOD.

ENDCLASS.

"!@testing SRVB:ZRAP400_UI_TRAVEL_SSC_O2
CLASS ltc_DELETE_ENTITY DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-METHODS:
      class_setup RAISING cx_static_check,
      class_teardown.

    METHODS:
      setup,
      teardown,
      delete_entity FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_DELETE_ENTITY IMPLEMENTATION.

  METHOD class_setup.
    ltc_helper=>helper_class_setup( ).
  ENDMETHOD.

  METHOD class_teardown.
    ltc_helper=>helper_class_teardown( ).
  ENDMETHOD.

  METHOD setup.
    ltc_helper=>helper_setup( ).
  ENDMETHOD.

  METHOD teardown.
    ltc_helper=>helper_teardown( ).
  ENDMETHOD.

  METHOD delete_entity.

    "**********************************************************************
    "* 04) This method tests/calls a delete operation and
    "* check if the data are still available via EML and in the database
    "**********************************************************************
    TYPES: BEGIN OF  ty_entity_key,
             travelid TYPE /dmo/travel_id,
           END OF ty_entity_key.

    " set entity key
    DATA(ls_entity_key) = VALUE ty_entity_key( travelid = ltc_helper=>travel_mock_data[ 1 ]-travel_id ).

    " Navigate to the resource
    DATA(lo_resource) = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->navigate_with_key( ls_entity_key ).

    " Execute the request for fetching the etag
    DATA(lo_response_read) = lo_resource->create_request_for_read( )->execute( ).

    " check if the test travel instance exists in the environment .
    SELECT SINGLE * FROM zrap400_travSSC  WHERE travel_id EQ @ls_entity_key-travelid INTO @DATA(ls_travel_inst) ##WARN_OK.

    cl_abap_unit_assert=>assert_equals( msg = 'initial check'     act = sy-subrc                   exp = 0  ).
    cl_abap_unit_assert=>assert_equals( msg = 'description check' act = ls_travel_inst-description exp = ltc_helper=>travel_mock_data[ 1 ]-description ).

    " navigate to the resource and create a request for the delete operation
    lo_resource = ltc_helper=>mo_client_proxy->create_resource_for_entity_set( 'Travel' )->navigate_with_key( ls_entity_key ).
    DATA(lo_request_for_delete) = lo_resource->create_request_for_delete( ).

    " Set the ETag
    lo_response_read = lo_resource->create_request_for_read( )->execute( ).
    lo_request_for_delete->set_if_match( lo_response_read->get_etag(  ) ).

    " execute the delete request
    lo_request_for_delete->execute( ).

    " assert deletion from the database - deleted test travel instance should not exist in the environment .
    SELECT SINGLE * FROM zrap400_travSSC  WHERE travel_id EQ @ls_entity_key-travelid INTO @ls_travel_inst ##WARN_OK.
    cl_abap_unit_assert=>assert_equals( msg = 'db check after deletion' act = sy-subrc exp = 4 ).

    " Try Reading the deleted travel entity
    READ ENTITIES OF ZRAP400_C_Travel_SSC
      ENTITY Travel
      FIELDS ( description )
        WITH VALUE #( ( TravelID = ls_entity_key-travelid ) )
        RESULT DATA(read_travel)
        FAILED DATA(failed)
        REPORTED DATA(reported).

    cl_abap_unit_assert=>assert_not_initial( msg = 'read check after deletion' act = failed ).

  ENDMETHOD.

ENDCLASS.

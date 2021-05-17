"! @testing BDEF:ZRAP400_I_Travel_SSC
CLASS zrap400_tc_travel_eml_ssc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
     FOR TESTING
   RISK LEVEL HARMLESS
   DURATION SHORT.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA:
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment,
      begin_date           TYPE /dmo/begin_date,
      end_date             TYPE /dmo/end_date,
      agency_mock_data     TYPE STANDARD TABLE OF /dmo/agency,
      customer_mock_data   TYPE STANDARD TABLE OF /dmo/customer,
      carrier_mock_data    TYPE STANDARD TABLE OF /dmo/carrier,
      flight_mock_data     TYPE STANDARD TABLE OF /dmo/flight.

    CLASS-METHODS:
      " setup test double framework
      class_setup,
      " stop test doubles
      class_teardown.

    METHODS:
      " reset test doubles
      setup,
      " rollback any changes
      teardown,

      " CUT: deep create with action call and commit
      deep_create_with_action FOR TESTING RAISING cx_static_check.

ENDCLASS.



CLASS zrap400_tc_travel_eml_ssc IMPLEMENTATION.

  METHOD class_setup.

    " Create the test doubles for the underlying CDS entities
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
                      i_for_entities = VALUE #(
                        ( i_for_entity = 'ZRAP400_I_Travel_SSC' )
                        ( i_for_entity = 'ZRAP400_I_Booking_SSC' ) ) ).
    " create test doubles for additional used tables.
    sql_test_environment = cl_osql_test_environment=>create(
    i_dependency_list = VALUE #(
    ( '/DMO/AGENCY' )
    ( '/DMO/CUSTOMER' )
    ( '/DMO/CARRIER' )
    ( '/DMO/FLIGHT' ) ) ).


    " prepare the test data
    begin_date = cl_abap_context_info=>get_system_date( ) + 10.
    end_date   = cl_abap_context_info=>get_system_date( ) + 30.


    agency_mock_data   = VALUE #( ( agency_id = '987654' name = 'Agency 987654' ) ).
    customer_mock_data = VALUE #( ( customer_id = '987653' last_name = 'customer 987653' ) ).
    carrier_mock_data  = VALUE #( ( carrier_id = '123' name = 'carrier 123' ) ).
    flight_mock_data   = VALUE #( ( carrier_id = '123' connection_id = '9876' flight_date = begin_date
    price = '2000' currency_code = 'EUR' ) ).

  ENDMETHOD.

  METHOD class_teardown.

  ENDMETHOD.

  METHOD deep_create_with_action.

    " create a complete composition: Travel (root) + Booking (child)
    MODIFY ENTITIES OF ZRAP400_I_Travel_SSC
     ENTITY Travel
       CREATE SET FIELDS WITH
         VALUE #( (  %cid = 'ROOT1'
                     AgencyID      = agency_mock_data[ 1 ]-agency_id
                     CustomerID    = customer_mock_data[ 1 ]-customer_id
                     BeginDate     = begin_date
                     EndDate       = end_date
                     Description   = 'TestTravel 1'
                     BookingFee    = '10.5'
                     CurrencyCode  = 'EUR'
                     OverallStatus = 'O'
                ) )
       CREATE BY \_booking SET FIELDS WITH
         VALUE #( ( %cid_ref = 'ROOT1'
                    %target = VALUE #( ( %cid = 'BOOKING1'
                                         BookingDate   = begin_date
                                         CustomerID    = customer_mock_data[ 1 ]-customer_id
                                         CarrierID     = flight_mock_data[ 1 ]-carrier_id
                                         ConnectionID  = flight_mock_data[ 1 ]-connection_id
                                         FlightDate    = flight_mock_data[ 1 ]-flight_date
                                         FlightPrice   = flight_mock_data[ 1 ]-price
                                         CurrencyCode  = flight_mock_data[ 1 ]-currency_code
                                         BookingStatus = 'N'
                                      ) )
                ) )
 " execute action
 ENTITY Travel
   EXECUTE acceptTravel
     FROM VALUE #( ( %cid_ref = 'ROOT1' ) )

 " check result
 MAPPED   DATA(mapped)
 FAILED   DATA(failed)
 REPORTED DATA(reported).

    " expect no failures and messages
    cl_abap_unit_assert=>assert_initial( msg = 'failed'   act = failed ).
    cl_abap_unit_assert=>assert_initial( msg = 'reported' act = reported ).

    " expect a newly created record in mapped tables
    cl_abap_unit_assert=>assert_not_initial( msg = 'mapped-travel'  act = mapped-travel ).
    cl_abap_unit_assert=>assert_not_initial( msg = 'mapped-booking' act = mapped-booking ).

    " persist changes into the database (using the test doubles)
    COMMIT ENTITIES RESPONSES
      FAILED   DATA(commit_failed)
      REPORTED DATA(commit_reported).

    " no failures expected
    cl_abap_unit_assert=>assert_initial( msg = 'commit_failed'   act = commit_failed ).
    cl_abap_unit_assert=>assert_initial( msg = 'commit_reported' act = commit_reported ).

    " check the existence of the persisted travel entity (using the test doubles)
    SELECT * FROM ZRAP400_I_Travel_SSC INTO TABLE @DATA(lt_travel). "#EC CI_NOWHERE
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel from db' act = lt_travel ).



    " assert the generation of a travel ID (key) at creation
    cl_abap_unit_assert=>assert_not_initial( msg = 'travel-id' act = lt_travel[ 1 ]-TravelID ).
    " assert that the action has changed the overall status
    cl_abap_unit_assert=>assert_equals( msg = 'overall status' exp = 'A' act = lt_travel[ 1 ]-OverallStatus ).
    " assert the calculated total_price = SUM( flight_price ) + booking_fee
    cl_abap_unit_assert=>assert_equals( msg = 'total price incl. booking_fee' exp = '2010.50' act = lt_travel[ 1 ]-TotalPrice ).




    " check the existence of the persisted booking entity (using the test doubles)
    SELECT * FROM ZRAP400_I_Booking_SSC INTO TABLE @DATA(lt_booking). "#EC CI_NOWHERE
    cl_abap_unit_assert=>assert_not_initial( msg = 'booking from db' act = lt_booking ).




    " assert the generation of a booking ID (key) at creation
    cl_abap_unit_assert=>assert_not_initial( msg = 'booking-id' act = lt_booking[ 1 ]-BookingID ).



  ENDMETHOD.

  METHOD setup.

    " clear the test doubles per test
    cds_test_environment->clear_doubles(  ).
    sql_test_environment->clear_doubles(  ).
    " insert test data into test doubles
    sql_test_environment->insert_test_data( agency_mock_data   ).
    sql_test_environment->insert_test_data( customer_mock_data ).
    sql_test_environment->insert_test_data( carrier_mock_data  ).
    sql_test_environment->insert_test_data( flight_mock_data   ).


  ENDMETHOD.

  METHOD teardown.

    " clean up any involved entity
    ROLLBACK ENTITIES.

  ENDMETHOD.

ENDCLASS.

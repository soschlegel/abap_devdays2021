*"* use this source file for your ABAP unit test classes
*"* use this source file for your ABAP unit test classes
"! @testing BDEF:ZRAP400_I_TRAVEL_SSC
CLASS ltc_readonly_methods DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA:
      class_under_test     TYPE REF TO lhc_travel,               " the class to be tested
      cds_test_environment TYPE REF TO if_cds_test_environment,  " cds test double framework
      sql_test_environment TYPE REF TO if_osql_test_environment. " abap sql test double framework

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

      " CUT: validation method validate_status
      validate_overall_status FOR TESTING.

ENDCLASS.


CLASS ltc_readonly_methods IMPLEMENTATION.

  METHOD class_setup.

    " Create the class under Test
    " The class is abstract but can be constructed with the FOR TESTING
    CREATE OBJECT class_under_test FOR TESTING.
    " Create test doubles for database dependencies
    " The EML READ operation will then also access the test doubles
    cds_test_environment = cl_cds_test_environment=>create( i_for_entity = 'ZRAP400_I_Travel_SSC' ).
    cds_test_environment->enable_double_redirection( ).
    sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( '/DMO/CUSTOMER' ) ) ).

  ENDMETHOD.

  METHOD class_teardown.

    " stop mocking
    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).

  ENDMETHOD.

  METHOD setup.

    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).

  ENDMETHOD.

  METHOD teardown.

    " Clean up any involved entity
    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD validate_overall_status.

    " fill in test data
    DATA travel_mock_data TYPE STANDARD TABLE OF zrap400_travssc.
    travel_mock_data = VALUE #( ( travel_id = 42 overall_status = 'A' )
                                          ( travel_id = 43 overall_status = 'B' ) " invalid status
                                          ( travel_id = 44 overall_status = 'O' ) ).
    " insert test data into the cds test doubles
    cds_test_environment->insert_test_data( i_data = travel_mock_data ).
    " call the method to be tested
    TYPES: BEGIN OF ty_entity_key,
             travelID TYPE /dmo/travel_id,
           END OF ty_entity_key.


    DATA: failed      TYPE RESPONSE FOR FAILED LATE zrap400_i_travel_ssc,
          reported    TYPE RESPONSE FOR REPORTED LATE zrap400_i_travel_ssc,
          entity_keys TYPE STANDARD TABLE OF ty_entity_key.


    " specify test entity keys
    entity_keys = VALUE #( ( travelID = 42 ) ( travelID = 43 ) ( travelID = 44  ) ).


    " execute the validation
    class_under_test->validateStatus(
    EXPORTING
    keys     = CORRESPONDING #( entity_keys )
    CHANGING
    failed   = failed
    reported = reported
    ).


    " check that failed has the relevant travel_id
    cl_abap_unit_assert=>assert_not_initial( msg = 'failed' act = failed ).
    cl_abap_unit_assert=>assert_equals( msg = 'failed-travel-id' act = failed-travel[ 1 ]-TravelID exp = 43 ).


    " check that reported also has the correct travel_id, the %element flagged and a message posted
    cl_abap_unit_assert=>assert_not_initial( msg = 'reported' act = reported ).
    DATA(ls_reported_travel) = reported-travel[ 1 ].
    cl_abap_unit_assert=>assert_equals( msg = 'reported-travel-id' act = ls_reported_travel-TravelID  exp = 43 ).
    cl_abap_unit_assert=>assert_equals( msg = 'reported-%element'  act = ls_reported_travel-%element-OverallStatus  exp = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_bound(  msg = 'reported-%msg'      act = ls_reported_travel-%msg ).


  ENDMETHOD.

ENDCLASS.

"! @testing BDEF:ZRAP400_I_TRAVEL_SSC
CLASS ltc_writing_methods DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA:
      class_under_test     TYPE REF TO lhc_travel,               " the class to be tested
      cds_test_environment TYPE REF TO if_cds_test_environment.  " cds test double framework

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

      " CUT: action method  acceptTravel
      set_status_to_accepted FOR TESTING RAISING cx_static_check,

      set_status_to_open FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_writing_methods IMPLEMENTATION.

  METHOD class_setup.

    " Create the Class under Test
    " The class is abstract but can be constructed with the FOR TESTING
    CREATE OBJECT class_under_test FOR TESTING.
    " Create test doubles for database dependencies
    " The EML READ operation will then also access the test doubles
    cds_test_environment = cl_cds_test_environment=>create( i_for_entity = 'ZRAP400_I_Travel_SSC' ).
    cds_test_environment->enable_double_redirection( ).

  ENDMETHOD.

  METHOD class_teardown.

    " Stop mocking
    cds_test_environment->destroy( ).

  ENDMETHOD.

  METHOD setup.

    " Clear the content of the test double per test
    cds_test_environment->clear_doubles( ).

  ENDMETHOD.

  METHOD set_status_to_accepted.

    " fill in test data
    DATA travel_mock_data TYPE STANDARD TABLE OF zrap400_travSSC.
    travel_mock_data = VALUE #( ( travel_id = 42 overall_status = 'A' )
    ( travel_id = 43 overall_status = 'O' )
    ( travel_id = 44 overall_status = 'X' ) ).
    " insert test data into the cds test doubles
    cds_test_environment->insert_test_data( i_data = travel_mock_data ).


    " call the method to be tested
    TYPES: BEGIN OF  ty_entity_key,
             travelID TYPE /dmo/travel_id,
           END OF ty_entity_key.


    DATA:
      result      TYPE TABLE    FOR ACTION RESULT ZRAP400_i_Travel_SSC\\Travel~acceptTravel,
      mapped      TYPE RESPONSE FOR MAPPED EARLY ZRAP400_i_Travel_SSC,
      failed      TYPE RESPONSE FOR FAILED EARLY ZRAP400_i_Travel_SSC,
      reported    TYPE RESPONSE FOR REPORTED EARLY ZRAP400_i_Travel_SSC,
      entity_keys TYPE STANDARD TABLE OF ty_entity_key.


    " specify entity keys
    entity_keys = VALUE #( ( travelID = 42 ) ( travelID = 43 ) ( travelID = 44  ) ).


    " execute the action
    class_under_test->acceptTravel(
    EXPORTING
    keys     = CORRESPONDING #( entity_keys )
    CHANGING
    result   = result
    mapped   = mapped
    failed   = failed
    reported = reported
    ).


    cl_abap_unit_assert=>assert_initial( msg = 'mapped'   act = mapped ).
    cl_abap_unit_assert=>assert_initial( msg = 'failed'   act = failed ).
    cl_abap_unit_assert=>assert_initial( msg = 'reported' act = reported ).


    " expect input keys and output keys to be same and OverallStatus everywhere = 'A' (Accepted)
    DATA exp LIKE result.
    exp = VALUE #(  ( TravelID = 42  %param-TravelID = 42  %param-OverallStatus = 'A' )
    ( TravelID = 43  %param-TravelID = 43  %param-OverallStatus = 'A' )
    ( TravelID = 44  %param-TravelID = 44  %param-OverallStatus = 'A' ) ).


    " current result; copy only fields of interest - i.e. TravelID, %param-travel_id and %param-OverallStatus.
    DATA act LIKE result.
    act = CORRESPONDING #( result MAPPING TravelID = TravelID
    (  %param = %param MAPPING TravelID      = TravelID
    OverallStatus = OverallStatus
    EXCEPT * )
    EXCEPT * ).
    " sort data by travel id
    SORT act ASCENDING BY TravelID.
    cl_abap_unit_assert=>assert_equals( msg = 'action result'  exp = exp  act = act ).


    " additionally check by reading entity state
    READ ENTITY ZRAP400_i_Travel_SSC
    FIELDS ( TravelID OverallStatus ) WITH CORRESPONDING #( entity_keys )
    RESULT DATA(read_result).
    act = VALUE #( FOR t IN read_result ( TravelID             = t-TravelID
    %param-TravelID      = t-TravelID
    %param-OverallStatus = t-OverallStatus ) ).
    " sort read data
    SORT act ASCENDING BY TravelID.
    cl_abap_unit_assert=>assert_equals( msg = 'read result'  exp = exp  act = act ).

  ENDMETHOD.

  METHOD teardown.

    " Clean up any involved entity
    ROLLBACK ENTITIES.

  ENDMETHOD.

  METHOD set_status_to_open.

    " fill in test data
    DATA travel_mock_data TYPE STANDARD TABLE OF zrap400_travSSC.
    travel_mock_data = VALUE #( ( travel_id = 42 overall_status = 'A' )
                                ( travel_id = 43 overall_status = ''  )  " empty status
                                ( travel_id = 44 overall_status = 'X' ) ).
    " insert test data into the cds test doubles
    cds_test_environment->insert_test_data( i_data = travel_mock_data ).
    " call the method to be tested
    TYPES: BEGIN OF  ty_entity_key,
             travelID TYPE /dmo/travel_id,
           END OF ty_entity_key.

    DATA: reported    TYPE RESPONSE FOR REPORTED LATE ZRAP400_I_Travel_SSC,
          entity_keys TYPE STANDARD TABLE OF ty_entity_key.

    " specify entity keys
    entity_keys = VALUE #( ( travelID = 42 ) ( travelID = 43 ) ( travelID = 44  ) ).

    " execute the determination
    class_under_test->setStatusToOpen(
      EXPORTING
        keys     = CORRESPONDING #( entity_keys )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_initial( msg = 'reported' act = reported ).

    "check by reading entity state
    READ ENTITY ZRAP400_I_Travel_SSC
      FIELDS ( TravelID OverallStatus ) WITH CORRESPONDING #( entity_keys )
      RESULT DATA(lt_read_result).

    " current result; copy only fields of interest - i.e. TravelID, OverallStatus.
    DATA act LIKE lt_read_result.
    act = CORRESPONDING #( lt_read_result MAPPING TravelID      = TravelID
                                                  OverallStatus = OverallStatus
                                                  EXCEPT * ).
    " sort result by travel id
    SORT act ASCENDING BY TravelID.

    "expected result
    DATA exp LIKE lt_read_result.
    exp = VALUE #( ( TravelID = 42 OverallStatus = 'A' )
                   ( TravelID = 43 OverallStatus = 'O' )
                   ( TravelID = 44 OverallStatus = 'X' ) ).

    " assert result
    cl_abap_unit_assert=>assert_equals( msg = 'read result'  exp = exp  act = act ).

  ENDMETHOD.

ENDCLASS.

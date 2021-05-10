class ZRAP400_CL_GEN_DATA_SSC definition
  public
  final
  create public .

public section.

  interfaces IF_OO_ADT_CLASSRUN .
protected section.
private section.
ENDCLASS.



CLASS ZRAP400_CL_GEN_DATA_SSC IMPLEMENTATION.


METHOD IF_OO_ADT_CLASSRUN~MAIN.
      DELETE FROM ('zrap400_travSSC').
     " insert travel demo data
     INSERT ('zrap400_travSSC')  FROM (
         SELECT
           FROM /dmo/travel AS travel
           FIELDS
             travel~travel_id        AS travel_id,
             travel~agency_id        AS agency_id,
             travel~customer_id      AS customer_id,
             travel~begin_date       AS begin_date,
             travel~end_date         AS end_date,
             travel~booking_fee      AS booking_fee,
             travel~total_price      AS total_price,
             travel~currency_code    AS currency_code,
             travel~description      AS description,
             CASE travel~status    "Status [N(New) | P(Planned) | B(Booked) | X(Cancelled)]
               WHEN 'N' THEN 'O'
               WHEN 'P' THEN 'O'
               WHEN 'B' THEN 'A'
               ELSE 'X'
             END                     AS overall_status,  "Travel Status [A(Accepted) | O(Open) | X(Cancelled)]
             travel~createdby        AS created_by,
             travel~createdat        AS created_at,
             travel~lastchangedby    AS last_changed_by,
             travel~lastchangedat    AS last_changed_at
             ORDER BY travel_id UP TO 50 ROWS
       ).
     COMMIT WORK.
     " define FROM clause dynamically
     DATA: dyn_table_name TYPE string.
     dyn_table_name = | /dmo/booking    AS booking  |
                  && | JOIN { 'zrap400_travSSC' } AS z |
                  && | ON   booking~travel_id = z~travel_id |.
     DELETE FROM ('zrap400_bookSSC').
     " insert booking demo data
     INSERT ('zrap400_bookSSC') FROM (
         SELECT
           FROM (dyn_table_name)
           FIELDS
             z~travel_id             AS travel_id           ,
             booking~booking_id      AS booking_id            ,
             booking~booking_date    AS booking_date          ,
             booking~customer_id     AS customer_id           ,
             booking~carrier_id      AS carrier_id            ,
             booking~connection_id   AS connection_id         ,
             booking~flight_date     AS flight_date           ,
             booking~flight_price    AS flight_price          ,
             booking~currency_code   AS currency_code         ,
             CASE z~overall_status    ""Travel Status [A(Accepted) | O(Open) | X(Cancelled)]
               WHEN 'O' THEN 'N'
               WHEN 'P' THEN 'N'
               WHEN 'A' THEN 'B'
               ELSE 'X'
             END                     AS booking_status,   "Booking Status [N(New) | B(Booked) | X(Cancelled)]
             z~last_changed_at       AS last_changed_at
       ).
     COMMIT WORK.
ENDMETHOD.
ENDCLASS.

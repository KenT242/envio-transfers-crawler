CREATE OR REPLACE FUNCTION safe_record_to_jsonb(input_record RECORD)
      RETURNS JSONB
      LANGUAGE plpgsql
      AS $$
      DECLARE
          json_result JSONB;
      BEGIN
          -- Convert the record into a JSONB object, iterate over each field
          SELECT jsonb_object_agg(d.key, 
                                  CASE 
                                      WHEN jsonb_typeof(d.value) = 'array' THEN 
                                          CASE 
                                              WHEN jsonb_array_length(d.value) = 0 THEN '[]'::JSONB  -- Return empty array
                                              ELSE 
                                                  (
                                                      SELECT jsonb_agg(
                                                          CASE 
                                                              WHEN jsonb_typeof(elem) = 'number' THEN to_jsonb(elem::TEXT)
                                                              ELSE elem
                                                          END
                                                      )
                                                      FROM jsonb_array_elements(d.value) AS elem
                                                  )
                                          END
                                      WHEN jsonb_typeof(d.value) = 'number' THEN to_jsonb(d.value::TEXT)
                                      ELSE d.value
                                  END)
          INTO json_result
          FROM jsonb_each(to_jsonb(input_record)) AS d;

          RETURN json_result;
      END;
      $$;

CREATE OR REPLACE FUNCTION copy_table_to_entity_history(source_table_name TEXT)
      RETURNS VOID AS $$
      DECLARE
          row RECORD;
          sql_query TEXT;
      BEGIN
          -- Dynamically construct the query to select all rows from the given source table
          sql_query := 'SELECT * FROM ' || quote_ident(source_table_name);
          
          -- Loop through each row in the dynamically selected table
          FOR row IN EXECUTE sql_query LOOP
              -- Insert the serialized JSON and other provided values into the entity_history table
              INSERT INTO entity_history (
                entity_id,
                block_timestamp,
                chain_id,
                block_number,
                log_index,
                entity_type,
                params
              )
              VALUES (
                row.id,
                0,
                0,
                0,
                0,
                source_table_name::entity_type,
                safe_record_to_jsonb(row)
              );
          END LOOP;
      END;
      $$ LANGUAGE plpgsql;
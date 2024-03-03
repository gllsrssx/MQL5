struct economicNews
{
   MqlCalendarEvent event;
   MqlCalendarValue value;
   MqlCalendarCountry country;
};

void createEconomicNews(MqlCalendarEvent &event, MqlCalendarValue &value, MqlCalendarCountry &country, economicNews &nieuws)
{

   nieuws.value = value;
   nieuws.event = event;
   nieuws.country = country;
}

string newsToString(economicNews &nieuws)
{

   string strNews = "";
   strNews += ((string)nieuws.event.id + ";");
   strNews += ((string)nieuws.event.type + ";");
   strNews += ((string)nieuws.event.sector + ";");
   strNews += ((string)nieuws.event.frequency + ";");
   strNews += ((string)nieuws.event.time_mode + ";");
   strNews += ((string)nieuws.event.country_id + ";");
   strNews += ((string)nieuws.event.unit + ";");
   strNews += ((string)nieuws.event.importance + ";");
   strNews += ((string)nieuws.event.multiplier + ";");
   strNews += ((string)nieuws.event.digits + ";");
   strNews += (nieuws.event.source_url + ";");
   strNews += (nieuws.event.event_code + ";");
   strNews += (nieuws.event.name + ";");
   strNews += ((string)nieuws.value.id + ";");
   strNews += ((string)nieuws.value.event_id + ";");
   strNews += ((string)(long)nieuws.value.time + ";");
   strNews += ((string)(long)nieuws.value.period + ";");
   strNews += ((string)nieuws.value.revision + ";");
   strNews += ((string)nieuws.value.actual_value + ";");
   strNews += ((string)nieuws.value.prev_value + ";");
   strNews += ((string)nieuws.value.revised_prev_value + ";");
   strNews += ((string)nieuws.value.forecast_value + ";");
   strNews += ((string)nieuws.value.impact_type + ";");
   strNews += ((string)nieuws.country.id + ";");
   strNews += ((string)nieuws.country.name + ";");
   strNews += ((string)nieuws.country.code + ";");
   strNews += ((string)nieuws.country.currency + ";");
   strNews += ((string)nieuws.country.currency_symbol + ";");
   strNews += ((string)nieuws.country.url_name);

   return strNews;
}

bool stringToNews(string newsStr, economicNews &nieuws)
{

   string tokens[];

   if (StringSplit(newsStr, ';', tokens) == 29)
   {

      nieuws.event.id = (ulong)tokens[0];
      nieuws.event.type = (ENUM_CALENDAR_EVENT_TYPE)tokens[1];
      nieuws.event.sector = (ENUM_CALENDAR_EVENT_SECTOR)tokens[2];
      nieuws.event.frequency = (ENUM_CALENDAR_EVENT_FREQUENCY)tokens[3];
      nieuws.event.time_mode = (ENUM_CALENDAR_EVENT_TIMEMODE)tokens[4];
      nieuws.event.country_id = (ulong)tokens[5];
      nieuws.event.unit = (ENUM_CALENDAR_EVENT_UNIT)tokens[6];
      nieuws.event.importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)tokens[7];
      nieuws.event.multiplier = (ENUM_CALENDAR_EVENT_MULTIPLIER)tokens[8];
      nieuws.event.digits = (uint)tokens[9];
      nieuws.event.source_url = tokens[10];
      nieuws.event.event_code = tokens[11];
      nieuws.event.name = tokens[12];
      nieuws.value.id = (ulong)tokens[13];
      nieuws.value.event_id = (ulong)tokens[14];
      nieuws.value.time = (datetime)(long)tokens[15];
      nieuws.value.period = (datetime)(long)tokens[16];
      nieuws.value.revision = (int)tokens[17];
      nieuws.value.actual_value = (long)tokens[18];
      nieuws.value.prev_value = (long)tokens[19];
      nieuws.value.revised_prev_value = (long)tokens[20];
      nieuws.value.forecast_value = (long)tokens[21];
      nieuws.value.impact_type = (ENUM_CALENDAR_EVENT_IMPACT)tokens[22];
      nieuws.country.id = (ulong)tokens[23];
      nieuws.country.name = tokens[24];
      nieuws.country.code = tokens[25];
      nieuws.country.currency = tokens[26];
      nieuws.country.currency_symbol = tokens[27];
      nieuws.country.url_name = tokens[28];

      return true;
   }

   return false;
}

void downloadCountryNews(string countryCode)
{

   int fileHandle = FileOpen("news_" + countryCode + ".csv", FILE_WRITE | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      MqlCalendarValue values[];

      if (CalendarValueHistory(values, D'01.01.1970', TimeCurrent(), countryCode))
      {

         for (int i = 0; i < ArraySize(values); i += 1)
         {

            MqlCalendarEvent event;

            if (CalendarEventById(values[i].event_id, event))
            {

               MqlCalendarCountry country;

               if (CalendarCountryById(event.country_id, country))
               {

                  economicNews nieuws;
                  createEconomicNews(event, values[i], country, nieuws);
                  FileWrite(fileHandle, newsToString(nieuws));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of nieuws download for " + countryCode);
}

void downloadNews()
{

   int fileHandle = FileOpen("news_" + ".csv", FILE_WRITE | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      MqlCalendarValue values[];

      if (CalendarValueHistory(values, D'01.01.1970', TimeCurrent()))
      {

         for (int i = 0; i < ArraySize(values); i += 1)
         {

            MqlCalendarEvent event;

            if (CalendarEventById(values[i].event_id, event))
            {

               MqlCalendarCountry country;

               if (CalendarCountryById(event.country_id, country))
               {

                  economicNews nieuws;
                  createEconomicNews(event, values[i], country, nieuws);
                  FileWrite(fileHandle, newsToString(nieuws));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of nieuws download ");
}

bool getBTnews(long period, economicNews &nieuws[])
{

   ArrayResize(nieuws, 0);
   int fileHandle = FileOpen("news_" + ".csv", FILE_READ | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      while (!FileIsEnding(fileHandle))
      {

         economicNews n;
         if (stringToNews(FileReadString(fileHandle), n))
         {

            if (n.value.time < TimeCurrent() + period && n.value.time > TimeCurrent() - period)
            {

               ArrayResize(nieuws, ArraySize(nieuws) + 1);
               nieuws[ArraySize(nieuws) - 1] = n;
            }
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

bool getBTnewsCountry(long period, string countryCode, economicNews &nieuws[])
{

   ArrayResize(nieuws, 0);
   int fileHandle = FileOpen("news_" + countryCode + ".csv", FILE_READ | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      while (!FileIsEnding(fileHandle))
      {

         economicNews n;
         if (stringToNews(FileReadString(fileHandle), n))
         {

            if (n.value.time < TimeCurrent() + period && n.value.time > TimeCurrent() - period)
            {

               ArrayResize(nieuws, ArraySize(nieuws) + 1);
               nieuws[ArraySize(nieuws) - 1] = n;
            }
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

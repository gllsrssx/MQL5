struct economicNews
{
   MqlCalendarEvent event;
   MqlCalendarValue value;
   MqlCalendarCountry country;
};

void createEconomicNews(MqlCalendarEvent &event, MqlCalendarValue &value, MqlCalendarCountry &country, economicNews &newsBT)
{

   newsBT.value = value;
   newsBT.event = event;
   newsBT.country = country;
}

string newsToString(economicNews &newsBT)
{

   string strNews = "";
   strNews += ((string)newsBT.event.id + ";");
   strNews += ((string)newsBT.event.type + ";");
   strNews += ((string)newsBT.event.sector + ";");
   strNews += ((string)newsBT.event.frequency + ";");
   strNews += ((string)newsBT.event.time_mode + ";");
   strNews += ((string)newsBT.event.country_id + ";");
   strNews += ((string)newsBT.event.unit + ";");
   strNews += ((string)newsBT.event.importance + ";");
   strNews += ((string)newsBT.event.multiplier + ";");
   strNews += ((string)newsBT.event.digits + ";");
   strNews += (newsBT.event.source_url + ";");
   strNews += (newsBT.event.event_code + ";");
   strNews += (newsBT.event.name + ";");
   strNews += ((string)newsBT.value.id + ";");
   strNews += ((string)newsBT.value.event_id + ";");
   strNews += ((string)(long)newsBT.value.time + ";");
   strNews += ((string)(long)newsBT.value.period + ";");
   strNews += ((string)newsBT.value.revision + ";");
   strNews += ((string)newsBT.value.actual_value + ";");
   strNews += ((string)newsBT.value.prev_value + ";");
   strNews += ((string)newsBT.value.revised_prev_value + ";");
   strNews += ((string)newsBT.value.forecast_value + ";");
   strNews += ((string)newsBT.value.impact_type + ";");
   strNews += ((string)newsBT.country.id + ";");
   strNews += ((string)newsBT.country.name + ";");
   strNews += ((string)newsBT.country.code + ";");
   strNews += ((string)newsBT.country.currency + ";");
   strNews += ((string)newsBT.country.currency_symbol + ";");
   strNews += ((string)newsBT.country.url_name);

   return strNews;
}

bool stringToNews(string newsStr, economicNews &newsBT)
{

   string tokens[];

   if (StringSplit(newsStr, ';', tokens) == 29)
   {

      newsBT.event.id = (ulong)tokens[0];
      newsBT.event.type = (ENUM_CALENDAR_EVENT_TYPE)tokens[1];
      newsBT.event.sector = (ENUM_CALENDAR_EVENT_SECTOR)tokens[2];
      newsBT.event.frequency = (ENUM_CALENDAR_EVENT_FREQUENCY)tokens[3];
      newsBT.event.time_mode = (ENUM_CALENDAR_EVENT_TIMEMODE)tokens[4];
      newsBT.event.country_id = (ulong)tokens[5];
      newsBT.event.unit = (ENUM_CALENDAR_EVENT_UNIT)tokens[6];
      newsBT.event.importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)tokens[7];
      newsBT.event.multiplier = (ENUM_CALENDAR_EVENT_MULTIPLIER)tokens[8];
      newsBT.event.digits = (uint)tokens[9];
      newsBT.event.source_url = tokens[10];
      newsBT.event.event_code = tokens[11];
      newsBT.event.name = tokens[12];
      newsBT.value.id = (ulong)tokens[13];
      newsBT.value.event_id = (ulong)tokens[14];
      newsBT.value.time = (datetime)(long)tokens[15];
      newsBT.value.period = (datetime)(long)tokens[16];
      newsBT.value.revision = (int)tokens[17];
      newsBT.value.actual_value = (long)tokens[18];
      newsBT.value.prev_value = (long)tokens[19];
      newsBT.value.revised_prev_value = (long)tokens[20];
      newsBT.value.forecast_value = (long)tokens[21];
      newsBT.value.impact_type = (ENUM_CALENDAR_EVENT_IMPACT)tokens[22];
      newsBT.country.id = (ulong)tokens[23];
      newsBT.country.name = tokens[24];
      newsBT.country.code = tokens[25];
      newsBT.country.currency = tokens[26];
      newsBT.country.currency_symbol = tokens[27];
      newsBT.country.url_name = tokens[28];

      return true;
   }

   return false;
}

void downloadNews()
{

   int fileHandle = FileOpen("news" + ".csv", FILE_WRITE | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      MqlCalendarValue values[];

      if (CalendarValueHistory(values, StringToTime("01.01.1970"), TimeCurrent()))
      {

         for (int i = 0; i < ArraySize(values); i += 1)
         {

            MqlCalendarEvent event;

            if (CalendarEventById(values[i].event_id, event))
            {

               MqlCalendarCountry country;

               if (CalendarCountryById(event.country_id, country))
               {

                  economicNews newsBT;
                  createEconomicNews(event, values[i], country, newsBT);
                  FileWrite(fileHandle, newsToString(newsBT));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of news download ");
}

bool getBTnews(long period, economicNews &newsBT[])
{

   ArrayResize(newsBT, 0);
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

               ArrayResize(newsBT, ArraySize(newsBT) + 1);
               newsBT[ArraySize(newsBT) - 1] = n;
            }
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

void downloadCountryNews(string countryCode)
{

   int fileHandle = FileOpen("news_" + countryCode + ".csv", FILE_WRITE | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      MqlCalendarValue values[];

      if (CalendarValueHistory(values, StringToTime("01.01.1970"), TimeCurrent(), countryCode))
      {

         for (int i = 0; i < ArraySize(values); i += 1)
         {

            MqlCalendarEvent event;

            if (CalendarEventById(values[i].event_id, event))
            {

               MqlCalendarCountry country;

               if (CalendarCountryById(event.country_id, country))
               {

                  economicNews newsBT;
                  createEconomicNews(event, values[i], country, newsBT);
                  FileWrite(fileHandle, newsToString(newsBT));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of news download for " + countryCode);
}

bool getBTnewsAll(economicNews &news[])
{

   ArrayResize(news, 0);
   int fileHandle = FileOpen("news_" + ".csv", FILE_READ | FILE_COMMON);

   if (fileHandle != INVALID_HANDLE)
   {

      while (!FileIsEnding(fileHandle))
      {

         economicNews n;
         if (stringToNews(FileReadString(fileHandle), n))
         {

            ArrayResize(news, ArraySize(news) + 1);
            news[ArraySize(news) - 1] = n;
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

bool getBTnewsCountry(long period, string countryCode, economicNews &news[])
{

   ArrayResize(news, 0);
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

               ArrayResize(news, ArraySize(news) + 1);
               news[ArraySize(news) - 1] = n;
            }
         }
      }

      FileClose(fileHandle);
      return true;
   }

   FileClose(fileHandle);
   return false;
}

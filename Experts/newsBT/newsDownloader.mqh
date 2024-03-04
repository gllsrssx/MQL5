struct economicNews
{
   MqlCalendarEvent event;
   MqlCalendarValue value;
   MqlCalendarCountry country;
};

void createEconomicNews(MqlCalendarEvent &event, MqlCalendarValue &value, MqlCalendarCountry &country, economicNews &news)
{

   news.value = value;
   news.event = event;
   news.country = country;
}

string newsToString(economicNews &news)
{

   string strNews = "";
   strNews += ((string)news.event.id + ";");
   strNews += ((string)news.event.type + ";");
   strNews += ((string)news.event.sector + ";");
   strNews += ((string)news.event.frequency + ";");
   strNews += ((string)news.event.time_mode + ";");
   strNews += ((string)news.event.country_id + ";");
   strNews += ((string)news.event.unit + ";");
   strNews += ((string)news.event.importance + ";");
   strNews += ((string)news.event.multiplier + ";");
   strNews += ((string)news.event.digits + ";");
   strNews += (news.event.source_url + ";");
   strNews += (news.event.event_code + ";");
   strNews += (news.event.name + ";");
   strNews += ((string)news.value.id + ";");
   strNews += ((string)news.value.event_id + ";");
   strNews += ((string)(long)news.value.time + ";");
   strNews += ((string)(long)news.value.period + ";");
   strNews += ((string)news.value.revision + ";");
   strNews += ((string)news.value.actual_value + ";");
   strNews += ((string)news.value.prev_value + ";");
   strNews += ((string)news.value.revised_prev_value + ";");
   strNews += ((string)news.value.forecast_value + ";");
   strNews += ((string)news.value.impact_type + ";");
   strNews += ((string)news.country.id + ";");
   strNews += ((string)news.country.name + ";");
   strNews += ((string)news.country.code + ";");
   strNews += ((string)news.country.currency + ";");
   strNews += ((string)news.country.currency_symbol + ";");
   strNews += ((string)news.country.url_name);

   return strNews;
}

bool stringToNews(string newsStr, economicNews &news)
{

   string tokens[];

   if (StringSplit(newsStr, ';', tokens) == 29)
   {

      news.event.id = (ulong)tokens[0];
      news.event.type = (ENUM_CALENDAR_EVENT_TYPE)tokens[1];
      news.event.sector = (ENUM_CALENDAR_EVENT_SECTOR)tokens[2];
      news.event.frequency = (ENUM_CALENDAR_EVENT_FREQUENCY)tokens[3];
      news.event.time_mode = (ENUM_CALENDAR_EVENT_TIMEMODE)tokens[4];
      news.event.country_id = (ulong)tokens[5];
      news.event.unit = (ENUM_CALENDAR_EVENT_UNIT)tokens[6];
      news.event.importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)tokens[7];
      news.event.multiplier = (ENUM_CALENDAR_EVENT_MULTIPLIER)tokens[8];
      news.event.digits = (uint)tokens[9];
      news.event.source_url = tokens[10];
      news.event.event_code = tokens[11];
      news.event.name = tokens[12];
      news.value.id = (ulong)tokens[13];
      news.value.event_id = (ulong)tokens[14];
      news.value.time = (datetime)(long)tokens[15];
      news.value.period = (datetime)(long)tokens[16];
      news.value.revision = (int)tokens[17];
      news.value.actual_value = (long)tokens[18];
      news.value.prev_value = (long)tokens[19];
      news.value.revised_prev_value = (long)tokens[20];
      news.value.forecast_value = (long)tokens[21];
      news.value.impact_type = (ENUM_CALENDAR_EVENT_IMPACT)tokens[22];
      news.country.id = (ulong)tokens[23];
      news.country.name = tokens[24];
      news.country.code = tokens[25];
      news.country.currency = tokens[26];
      news.country.currency_symbol = tokens[27];
      news.country.url_name = tokens[28];

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

                  economicNews news;
                  createEconomicNews(event, values[i], country, news);
                  FileWrite(fileHandle, newsToString(news));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of news download for " + countryCode);
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

                  economicNews news;
                  createEconomicNews(event, values[i], country, news);
                  FileWrite(fileHandle, newsToString(news));
               }
            }
         }
      }
   }

   FileClose(fileHandle);

   Print("End of news download ");
}

bool getBTnews(long period, economicNews &news[])
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

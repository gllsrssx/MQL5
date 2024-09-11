#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "1.0"
#property description "This EA does grid trading and uses recovery zone hedge strategy to exit losses."

#include <Trade\Trade.mqh>
CTrade trade;

input int InpMagicNumber = 123456;              // Magic number
input int InpGridDistancePoints = 250;          // Distance between grid levels in points
input double InpRiskPerTrade = 0.1;             // Risk per trade as a percentage of the account balance
input double InpDrawdownThreshold = 1.0;        // Drawdown percentage to start recovery zone (0=off)
input bool InpPlot = false; // Plot

MqlTick tick;
MqlDateTime time;

double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
double gridDistancePoints = InpGridDistancePoints * tickSize;
double upperLevel = NormalizeDouble(MathCeil(SymbolInfoDouble(Symbol(), SYMBOL_ASK) / gridDistancePoints) * gridDistancePoints, Digits());
double lowerLevel = NormalizeDouble(MathFloor(SymbolInfoDouble(Symbol(), SYMBOL_BID) / gridDistancePoints) * gridDistancePoints, Digits());

int OnInit(){
    if (TimeCurrent() > StringToTime("2025.01.01 00:00:00")) {
        Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
        ExpertRemove();
        return(INIT_FAILED);
    }
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
    TimeToStruct(TimeCurrent(), time);
    SymbolInfoTick(Symbol(), tick);
    Main();
}

int maxPos=0;
void Main(){
    if(!IsBuyTradeAtLevel(upperLevel))TakeBuyTradeAtLevel(upperLevel);
    if(!IsSellTradeAtLevel(lowerLevel))TakeSellTradeAtLevel(lowerLevel);

    GetUpperLevel();
    GetLowerLevel();
    
    SetTakeProfit();
    
    Recovery();
    
   
  Hedger();
  int currPos = PositionCount();
  maxPos = currPos > maxPos ? currPos : maxPos;


    if(!InpPlot)return;
    Comment("time: ", tick.time,"\n",
            "tick: ", (string)tick.last,"\n",
            "UL: ", upperLevel,"\n",
            "LL: ", lowerLevel,"\n",
            "dir: ", GetLastDirection(),"\n",
            "recovery: ", recoveryFlag,"\n",
            "drawdown: ", NormalizeDouble(((AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY)) / AccountInfoDouble(ACCOUNT_BALANCE)) * 100, 2), "\n"            
            );
    
    if(!ObjectCreate(0, (string)upperLevel, OBJ_HLINE, 0, 0, upperLevel)) {
        Print("Failed to create upper level line. Error: ", GetLastError());
    } else {
        ObjectSetInteger(0, (string)upperLevel, OBJPROP_COLOR, clrBlue); // Set line color
    }
    if(!ObjectCreate(0, (string)lowerLevel, OBJ_HLINE, 0, 0, lowerLevel)) {
        Print("Failed to create upper level line. Error: ", GetLastError());
    } else {
        ObjectSetInteger(0, (string)lowerLevel, OBJPROP_COLOR, clrBlue); // Set line color
    }
    
}

void GetUpperLevel(){
    double multiplier = MathCeil(tick.ask / gridDistancePoints);
    upperLevel = NormalizeDouble(multiplier * gridDistancePoints, Digits());
    return ;
}

void GetLowerLevel(){
    double multiplier = MathFloor(tick.bid / gridDistancePoints);
    lowerLevel = NormalizeDouble(multiplier * gridDistancePoints, Digits());
    return ;
}

bool IsBuyTradeAtLevel(double level){
    if(recoveryFlag)return true;
    for (int i = PositionsTotal() - 1; i >= 0; i--){
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if (PositionGetString(POSITION_COMMENT) == (string)level && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) return true;   
    }
    return false;
}

bool IsSellTradeAtLevel(double level){
    if(recoveryFlag)return true;
    for (int i = PositionsTotal(); i >= 0; i--){
        if (!PositionGetTicket(i)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if (PositionGetString(POSITION_COMMENT) == (string)level && PositionGetInteger(POSITION_TYPE) == 1) return true;
    }
    return false;
}

void TakeBuyTradeAtLevel(double level){
    if(tick.ask <= level) return;
    double volume = Volume(1);
    while (volume > 0) {
    trade.Buy(volume>maxVol?maxVol:volume, Symbol(),0, 0, 0, (string)level);
    volume -= maxVol;
    }
}

void TakeSellTradeAtLevel(double level){
    if(tick.bid >= level) return;
    double volume = Volume(-1);
    while (volume > 0) {
    trade.Sell(volume>maxVol?maxVol:volume, Symbol(),0, 0, 0, (string)level);
    volume -= maxVol;
    }
}

void SetTakeProfit(){
    for (int i = PositionsTotal(); i >= 0; i--){
        ulong ticket = PositionGetTicket(i);
        if (!ticket || PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetDouble(POSITION_TP) != 0) continue;
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double takeProfitPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? entryPrice+gridDistancePoints : entryPrice-gridDistancePoints;
        trade.PositionModify(ticket, 0, takeProfitPrice);
    }
}

double Volume(int direction){
    double lastDirection = GetLastDirection();
    bool recoveryVolumeFlag = recoveryFlag && direction != lastDirection && direction != 0 && lastDirection != 0;
    double balance =  AccountInfoDouble(ACCOUNT_BALANCE);
    double riskMoney = balance * InpRiskPerTrade * 0.01;
    double moneyLotStep = gridDistancePoints / tickSize * tickValue * lotStep; 
    double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
    if (lots < minVol || lots == NULL) lots = minVol;
    return lots;
}

void Recovery(){
    int previousFlag = recoveryFlag;
    CheckRecoveryNeeded();
    if(!recoveryFlag)return;
    if(AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE)){
        CloseAllTrades();
        recoveryFlag = false;
        return;
    }

}

bool recoveryFlag = false;
void CheckRecoveryNeeded(){
    if (AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) * (1 - InpDrawdownThreshold * 0.01) && InpDrawdownThreshold > 0) recoveryFlag=true;
    if (recoveryFlag && AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) * (1 - InpDrawdownThreshold * 0.01) && !RecoveryPositionOpen()) recoveryFlag=false;
    return;
}

bool RecoveryPositionOpen(){
    double totalVolume = 0;
    double standardVolume = Volume(0);
    double positionsCount = PositionCount();
    double expectedTotalVolume = standardVolume*positionsCount;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        totalVolume += PositionGetDouble(POSITION_VOLUME);
    }
    if(totalVolume == expectedTotalVolume)return false;
    return true;
}

int GetLastDirection()
{
  double buyLots = 0;
  double sellLots = 0;
  int lastDirection = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket)) continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

    double posLots = PositionGetDouble(POSITION_VOLUME);
    double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double diff = MathAbs(posPrice - tick.last);
    double multiplier = diff / gridDistancePoints;

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
      buyLots+=posLots*multiplier;
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
      sellLots+=posLots*multiplier;
    }
  }

  if(buyLots > sellLots)
    {
     lastDirection = 1;
    }
   else if(buyLots < sellLots)
    {
     lastDirection = -1;
    }
    else
      {
       lastDirection =0;
      }
  return lastDirection;
}

int PositionCount()
{
  int count = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;
    count++;
  }
  return count;
}

void CloseAllTrades()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        trade.PositionClose(ticket);
    }
}


enum NEWS_IMPORTANCE_ENUM
{
  IMPORTANCE_ALL,    // ALL
  IMPORTANCE_HIGH,   // HIGH
  IMPORTANCE_MEDIUM, // MEDIUM
  IMPORTANCE_LOW,    // LOW
  IMPORTANCE_BOTH,   // H&M
  IMPORTANCE_NOT_LOW,// NL
};
input NEWS_IMPORTANCE_ENUM InpImportance = IMPORTANCE_ALL; // News importance
bool InpImportance_high = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_HIGH || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_moderate = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_MEDIUM || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_low = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_LOW;
bool InpImportance_all = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_NOT_LOW;

MqlCalendarValue news[];

double upperLine, lowerLine, baseLots;

struct economicNews
{
  MqlCalendarEvent event;
  MqlCalendarValue value;
  MqlCalendarCountry country;
};
economicNews newsHist[];
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
  int fileHandle = FileOpen("news" + ".csv", FILE_READ | FILE_COMMON);

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

int totalBarsCal;
void GetCalendarValue()
{
  if (!IsNewBar(PERIOD_D1, barsTotal1))
    return;
  if (MQLInfoInteger(MQL_TESTER))
  {
    ArrayFree(newsHist);
    getBTnews(PeriodSeconds(PERIOD_D1), newsHist);
    return;
  }
  datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
  datetime endTime = startTime + PeriodSeconds(PERIOD_D1);
  ArrayFree(news);
  CalendarValueHistory(news, startTime, endTime, NULL, NULL);
}

string lastNewsEvent;
datetime iDay;
datetime holiDay;
int totalBarsEvent;
bool IsNewsEvent()
{
  if (!IsNewBar(PERIOD_M1, barsTotal2) || upperLine > 0 || lowerLine > 0 || RecoveryPositionOpen())
    return false;

  if(!recoveryFlag) return false;

  iDay = iTime(Symbol(), PERIOD_D1, 0);
  if(holiDay==iDay)return false;

  GetCalendarValue();
  int amount = MQLInfoInteger(MQL_TESTER) ? ArraySize(newsHist) : ArraySize(news);
  for (int i = amount - 1; i >= 0; i--)
  {
    MqlCalendarEvent event;
    MqlCalendarValue value;
    MqlCalendarCountry country;

    if (MQLInfoInteger(MQL_TESTER))
    {
      event = newsHist[i].event;
      value = newsHist[i].value;
      country = newsHist[i].country;
    }
    else
    {
      CalendarEventById(news[i].event_id, event);
      CalendarValueById(news[i].id, value);
      CalendarCountryById(event.country_id, country);
    }
    
    if (!(country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT)))
      continue;
    if (event.type == CALENDAR_TYPE_HOLIDAY && (value.time > iDay && value.time < iDay+PeriodSeconds(PERIOD_D1))) {holiDay=iDay;return false;} 
    if (event.importance == CALENDAR_IMPORTANCE_NONE && !InpImportance_all) continue;
    if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low) continue;
    if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate) continue;
    if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high) continue;
    
    if (value.time == iTime(Symbol(), PERIOD_M1, 0))
    {
      lastNewsEvent = country.currency +(string)event.importance +" "+ event.name+" "+(string)value.time;
      Print(lastNewsEvent);
      return true;
    }
  }
  return false;
}

bool arrayContains(string &arr[], string value)
{
  for (int i = ArraySize(arr) - 1; i >= 0; i--)
  {
    if (arr[i] == value)
      return true;
  }
  return false;
}

int barsTotal1, barsTotal2, barsTotal3;
bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal)
    return false;

  barsTotal = bars;
  return true;
}

double GetPositionSize()
{
   double lastDirection = GetLastDirection();
    double recoveryLots = 0;
    if(recoveryFlag) {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket)) continue;
            if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            long posType = PositionGetInteger(POSITION_TYPE);
            double posLots = PositionGetDouble(POSITION_VOLUME);
            double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double diff = MathAbs(posPrice - tick.last) + gridDistancePoints;
            double multiplier = diff / gridDistancePoints;
           if((lastDirection == 1 && POSITION_TYPE_BUY) ||(lastDirection == -1 && POSITION_TYPE_SELL)){
            recoveryLots -= posLots*multiplier;
            }else{
            recoveryLots += posLots*multiplier;
           }
        }
    }
    double lots = MathCeil((Volume(0) + recoveryLots) / lotStep) * lotStep;
    if (lots < minVol || lots == NULL) lots = minVol;
    return lots;
}

void CalculateZone()
{
  if (RecoveryPositionOpen() || !IsNewsEvent())
    return;
  
  upperLine = upperLevel;
  lowerLine = lowerLevel;
  Print("INFO: Calculated zone.");
}

int lastRecoveryDirection = 0;
void TakeTrade()
{
  
  if(holiDay==iDay && !RecoveryPositionOpen())return;
  if (upperLine == 0 || lowerLine == 0)
    return;

  int lastDirections = GetLastDirection();
  double lots = GetPositionSize();
  double maxlot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  
  if (tick.ask >=  upperLine && lastDirections != 1) {
    while (lots > 0){
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2),NULL,0,0,0,lastNewsEvent);
      lots -= maxlot;
      lastRecoveryDirection = 1;
    }
  }
  if (tick.bid <=  lowerLine && lastDirections != -1) {
    while (lots > 0){
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2),NULL,0,0,0,lastNewsEvent);
      lots -= maxlot;
        lastRecoveryDirection = -1;
    }
  }
}

void CloseTrades()
{
  if (!RecoveryPositionOpen())
    return;
  
  if (AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) * (1 + InpRiskPerTrade * 1 * 0.01))
  {
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
        continue;
      if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
        continue;

      trade.PositionClose(ticket);
    }
    upperLine = 0;
    lowerLine = 0;
    recoveryFlag = false;
    lastRecoveryDirection = 0;
  }
}

datetime drawStartTime=0;
void ShowLines()
{
  if (!InpPlot) return;   
  if (upperLine > 0 && lowerLine > 0)
{
    if(drawStartTime==0) drawStartTime = TimeCurrent();
    datetime drawStopTime = TimeCurrent();
    double tpPoints = (upperLine - lowerLine) * 1;
    
    int posC = PositionCount();
    double ul = upperLine;
    double ll = lowerLine;
    // Create the rectangle for the range
    ObjectCreate(0, "rangeBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ll);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the upper TP box
    ObjectCreate(0, "rangeAboveBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ul+tpPoints);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the lower TP box
    ObjectCreate(0, "rangeBelowBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ll, drawStopTime, ll-tpPoints);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box
   }
   else
     {
         drawStartTime=0;
     }
}

int MaxHedges()
{
  static int maxHedges = 0;
  int hedges = PositionCount();
  if (hedges < 1)
    return maxHedges;
  if (hedges > maxHedges)
    maxHedges = hedges;
  return maxHedges;
}

void Hedger()
{
  CloseTrades();
  CalculateZone();
  TakeTrade();
  ShowLines();
}





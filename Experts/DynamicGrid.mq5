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
input double InpRiskHedgeMultiplier = 1.1;      // Risk multiplier for hedge trades
input double InpFixedLot= 0; // Fixed risk (0=off)
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

void Main(){
    
    Recovery();
    
    if(!IsBuyTradeAtLevel(upperLevel))TakeBuyTradeAtLevel(upperLevel);
    if(!IsSellTradeAtLevel(lowerLevel))TakeSellTradeAtLevel(lowerLevel);

    GetUpperLevel();
    GetLowerLevel();
    
    SetTakeProfit();
    
    
    if(!InpPlot)return;
    Comment("time: ", tick.time,"\n",
            "tick: ", (string)tick.last,"\n",
            "UL: ", upperLevel,"\n",
            "LL: ", lowerLevel,"\n",
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
    for (int i = PositionsTotal() - 1; i >= 0; i--){
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if (PositionGetString(POSITION_COMMENT) == (string)level && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if (volume != Volume(1) && tick.bid >= entryPrice) {
                trade.PositionClose(ticket);
                return false;
            } 
            return true;
        }
    }
    return false;
}

bool IsSellTradeAtLevel(double level){
    for (int i = PositionsTotal(); i >= 0; i--){
        if (!PositionGetTicket(i)) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if (PositionGetString(POSITION_COMMENT) == (string)level && PositionGetInteger(POSITION_TYPE) == 1) {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if (volume != Volume(-1) && tick.ask <= entryPrice) {
                trade.PositionClose(PositionGetTicket(i));
                return false;
            } 
            return true;
        }
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
   if(recoveryFlag)return;
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
    if(InpFixedLot > 0) lots = InpFixedLot;
    double recoveryLots = 0;
    if(recoveryVolumeFlag) {
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
            recoveryLots += posLots * multiplier;
        }
       // recoveryLots-=lots;
        recoveryLots = recoveryLots * InpRiskHedgeMultiplier;
    }
    lots = MathRound((lots + recoveryLots) / lotStep) * lotStep;
    if (lots < minVol || lots == NULL) lots = minVol;
    return lots;
}

void Recovery(){
    int previousFlag = recoveryFlag;
    CheckRecoveryNeeded();
    if(!recoveryFlag)return;
    if(AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE)){
        //CloseAllTrades();
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

//+------------------------------------------------------------------+
//|                                                MACD_Strategy.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade Trading;
CPositionInfo Position;



input int FastEMA_Period=12;
input int SlowEMA_Period=26;
input int SignalSMA_Period=9;

input double RiskPercent=0.01;
input int R2R=1;
input ENUM_TIMEFRAMES TimeFramee=PERIOD_H1;
double LotSize=0.01;

double TakeProfit;
double StopLoss;
double StoplossPoint=100;

bool TradeIsAllowerd=true;
bool IsBuy;


void OnTick()
  {
        double MACD_Histogram_1=MACDcalculator(true,_Symbol,PERIOD_CURRENT,PRICE_CLOSE,FastEMA_Period,SlowEMA_Period,SignalSMA_Period,1,5);
        double MACD_Histogram_2=MACDcalculator(true,_Symbol,PERIOD_CURRENT,PRICE_CLOSE,FastEMA_Period,SlowEMA_Period,SignalSMA_Period,2,5);    
        double MACD_Signal_1=MACDcalculator(false,_Symbol,PERIOD_CURRENT,PRICE_CLOSE,FastEMA_Period,SlowEMA_Period,SignalSMA_Period,1,5);
        double MACD_Signal_2=MACDcalculator(false,_Symbol,PERIOD_CURRENT,PRICE_CLOSE,FastEMA_Period,SlowEMA_Period,SignalSMA_Period,2,5);
        
        
        double Ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
        double Bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
        
        
        if(IsNewCanddle(TimeFramee)) TradeIsAllowerd=true; 
        if(PositionsTotal()==0 && TradeIsAllowerd)
        {
        
            if(MACD_Histogram_1>0 && MACD_Signal_1>0 && (MACD_Histogram_2<MACD_Signal_2 && MACD_Histogram_1>MACD_Signal_1))
            {
               
                  StopLoss=Ask-StoplossPoint*Point();
                  TakeProfit=Ask+R2R*StoplossPoint*Point();
                  LotSize=OptimumLotSize(_Symbol,Ask,StopLoss,RiskPercent);
                  Trading.Buy(LotSize,_Symbol,Ask,StopLoss,TakeProfit);
                  IsBuy=true;
                  TradeIsAllowerd=false;
            
            }
            if(MACD_Histogram_1<0 && MACD_Signal_1<0 && (MACD_Histogram_2>MACD_Signal_2 && MACD_Histogram_1<MACD_Signal_1))
            {
               StopLoss=Bid+StoplossPoint*Point();
               TakeProfit=Bid-R2R*StoplossPoint*Point();
               LotSize=OptimumLotSize(_Symbol,Bid,StopLoss,RiskPercent);
               Trading.Sell(LotSize,_Symbol,Bid,StopLoss,TakeProfit);
               IsBuy=false;
               TradeIsAllowerd=false;
            
            
            }
        
        
        
        
        }   
            
            
            
  }










double MACDcalculator (bool TrueForHistogram_FalseForSignal,string symbol, ENUM_TIMEFRAMES TimeFrame,ENUM_APPLIED_PRICE aplyedPrice,int FastEMA_Period,int SlowEMA_Period,int SignalSMA_Period,int shift, int BufferNumber=10)
{

   //cretaing an array for prices for MACD main line, MACD signal line
   double MACDMainLine[];
   double MACDSignalLine[];
   
   //Defining MACD and its parameters
   int MACDDef = iMACD(symbol,TimeFrame,FastEMA_Period,SlowEMA_Period,SignalSMA_Period,aplyedPrice);
   
   //Sorting price array from current data for MACD main line, MACD signal line
   ArraySetAsSeries(MACDMainLine,true);
   ArraySetAsSeries(MACDSignalLine,true);
   
   //Storing results after defining MA, line, current data for MACD main line, MACD signal line
   CopyBuffer(MACDDef,0,0,BufferNumber,MACDMainLine);
   CopyBuffer(MACDDef,1,0,BufferNumber,MACDSignalLine);
   
   //Get values of current data for MACD main line, MACD signal line
   double MACDMainLineVal = NormalizeDouble(MACDMainLine[shift],6);
   double MACDSignalLineVal = NormalizeDouble(MACDSignalLine[shift],6);
   
   if (TrueForHistogram_FalseForSignal)
   {
      return MACDMainLineVal;
   }
   else
   {
      return MACDSignalLineVal;
   }
   

}




double OptimumLotSize(string symbol,double EntryPoint, double StoppLoss, double RiskPercent)
{
      int            Diigit         =SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      double         OneLotValue    =MathPow(10,Diigit);
      
      double         ask            =SymbolInfoDouble("GBPUSD",SYMBOL_ASK);
      
      double         bid            =SymbolInfoDouble(symbol,SYMBOL_BID);
      
      string         BaseCurrency   =SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);
      string         ProfitCurency  =SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT); 
      string         AccountCurency =AccountInfoString(ACCOUNT_CURRENCY);
      
      double         AllowedLoss    =RiskPercent*AccountInfoDouble(ACCOUNT_EQUITY);
      double         LossPoint      =MathAbs(EntryPoint-StoppLoss);
      double         Lotsize;
      
      
      
      
      
      if (ProfitCurency==AccountCurency) 
         { 
         Lotsize=AllowedLoss/LossPoint; 
         Lotsize=NormalizeDouble(Lotsize/OneLotValue,2);
          
         return(Lotsize); 
         }
         
      else if (BaseCurrency==AccountCurency)
         {
         AllowedLoss=ask*AllowedLoss;  //// Allowed loss in Profit currency Example: USDCHF-----> Return allowed loss in CHF
         Lotsize=AllowedLoss/LossPoint; 
         Lotsize=NormalizeDouble(Lotsize/OneLotValue,2); 
         return(Lotsize);
         }
      
         else
         {
            string TransferCurrency=AccountCurency+ProfitCurency;
            ask=SymbolInfoDouble(TransferCurrency,SYMBOL_ASK);
            
            if(ask!=0) 
            {
               AllowedLoss=ask*AllowedLoss;  //// Allowed loss in Profit currency Example: USDCHF-----> Return allowed loss in CHF
               Lotsize=AllowedLoss/LossPoint; 
               Lotsize=NormalizeDouble(Lotsize/OneLotValue,2); 
               return(Lotsize);   
            
            }
            else
            {
               TransferCurrency=ProfitCurency+AccountCurency;
               ask=SymbolInfoDouble(TransferCurrency,SYMBOL_ASK);
               ask=1/ask;
               AllowedLoss=ask*AllowedLoss;  //// Allowed loss in Profit currency Example: USDCHF-----> Return allowed loss in CHF
               Lotsize=AllowedLoss/LossPoint; 
               Lotsize=NormalizeDouble(Lotsize/OneLotValue,2); 
               return(Lotsize);
            
            }
            
            if (ProfitCurency=="JPY") 
               { 
               Lotsize=AllowedLoss*1.5/LossPoint; 
               Lotsize=NormalizeDouble(Lotsize/OneLotValue,2);
                
               return(Lotsize); 
               }
                  
         return Lotsize; 
         }
          

}



///////////////// Is new Canddle? (Return a true rising edge when new canddle starts)////////////


bool IsNewCanddle (ENUM_TIMEFRAMES TimeFrame)
{

   static datetime LastCandleTime;
   datetime CurrentCandleTime=iTime(NULL,TimeFrame,0);//////// Current Candle Time=Time[0]
   if(LastCandleTime==CurrentCandleTime) return(false);
   else

      {
      LastCandleTime=CurrentCandleTime;
      return(true);
      }


}
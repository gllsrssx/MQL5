#property description "Exponential Moving Average"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_label1  "EMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrDeepSkyBlue,clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

input int                inpPeriod   =  14;         // Period
input ENUM_APPLIED_PRICE inpPrice    = PRICE_CLOSE; // Price

double val[],valc[];

int OnInit()
{
   SetIndexBuffer(0,val,INDICATOR_DATA);
   SetIndexBuffer(1,valc,INDICATOR_COLOR_INDEX);
         _ema.init(inpPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME,"Exponential Moving Average ("+(string)inpPeriod+")");
   return (INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int i=prev_calculated-1; if (i<0) i=0; for (; i<rates_total && !_StopFlag; i++)
   {
      val[i]  = _ema.calculate(getPrice(inpPrice,open,high,low,close,i),i,rates_total);
      valc[i] = (i>0) ? (val[i]>val[i-1]) ? 0 : (val[i]<val[i-1]) ? 1 : valc[i-1] : 0;
   }
   return (i);
}

class CEma
{
   private :
         double m_period;
         double m_alpha;
         double m_array[];
         int    m_arraySize;
   public :
      CEma() : m_period(1), m_alpha(1), m_arraySize(-1) { return; }
     ~CEma()                                            { return; }
    
     void init(int period)
      {
            m_period = (period>1) ? period : 1;
            m_alpha  = 2.0/(1.0+m_period);
      }
      double calculate(double value, int i, int bars)
      {
        if (m_arraySize<bars)
          { m_arraySize=ArrayResize(m_array,bars+500); if (m_arraySize<bars) return(0); }

            if (i>0)
                    m_array[i] = m_array[i-1]+m_alpha*(value-m_array[i-1]); 
            else    m_array[i] = value;
            return (m_array[i]);
         }   
};
CEma _ema;

template <typename T> 
double getPrice(ENUM_APPLIED_PRICE tprice, T& open[], T& high[], T& low[], T& close[], int i)
{
   switch(tprice)
   {
         case PRICE_CLOSE:     return(close[i]);
         case PRICE_OPEN:      return(open[i]);
         case PRICE_HIGH:      return(high[i]);
         case PRICE_LOW:       return(low[i]);
         case PRICE_MEDIAN:    return((high[i]+low[i])/2.0);
         case PRICE_TYPICAL:   return((high[i]+low[i]+close[i])/3.0);
         case PRICE_WEIGHTED:  return((high[i]+low[i]+close[i]+close[i])/4.0);
   }
   return(0);
}

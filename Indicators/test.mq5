#property description "Exponential Moving Average"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_label1  "EMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGreen,clrRed,clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

input int inpPeriod = 200;
input ENUM_APPLIED_PRICE inpPrice = PRICE_CLOSE;

double val[],valc[];

double calculateEma(ENUM_APPLIED_PRICE tprice, const double &open[], const double &high[], const double &low[], const double &close[], int i, int bars)
{
   return _ema.calculate(getPrice(tprice,open,high,low,close,i),i,bars);
}

double getPrice(ENUM_APPLIED_PRICE tprice, double open, double high, double low, double close) {
    switch(tprice) {
        case PRICE_CLOSE:     return close;
        case PRICE_OPEN:      return open;
        case PRICE_HIGH:      return high;
        case PRICE_LOW:       return low;
        case PRICE_MEDIAN:    return (high + low) / 2.0;
        case PRICE_TYPICAL:   return (high + low + close) / 3.0;
        case PRICE_WEIGHTED:  return (high + low + close + close) / 4.0;
        default:              return 0;
    }
}

int OnInit() {
    SetIndexBuffer(0,val,INDICATOR_DATA);
    SetIndexBuffer(1,valc,INDICATOR_COLOR_INDEX);
    return (INIT_SUCCEEDED);
}

bool isTrending(int i, const double &close[], bool isBullish) {
    for (int j = 5; j <= 50; j += 5) {
        if ((isBullish && close[i-j] <= val[i-j]) || (!isBullish && close[i-j] >= val[i-j])) return false;
    }
    return true;
}

int getColorIndex(int i, const double &close[]) {
    return (isTrending(i, close, true) && close[i] > val[i]) ? 0 : 
           (isTrending(i, close, false) && close[i] < val[i]) ? 1 : 2;
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
      val[i]  = calculateEMA(inpPrice,open,high,low,close,i,rates_total);
      valc[i] = getColorIndex(i, close);
   }
   return (i);
}


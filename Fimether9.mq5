//+------------------------------------------------------------------+
//|                                                     ManualEA.mq5 |
//|                                                              PZK |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "PZK"
#property link      "https://www.mql5.com"
#property version   "1.00"

// EA Imports
#include <ChartObjects\ChartObjectsLines.mqh>
#include <Trade\Trade.mqh>

// Imported Classes definition
CTrade trade; 
CChartObjectHLine hline;

// Enums Declaration
enum Fractionate {
   F1=0,    // Fractionate in 50%
   F2=1,   // Fractionate in 25%
   F3=2   // Fractionate in 12,5%
};
enum MarkChannel {
   AC=0,    // Auto
   SC=1,    // Static
};
enum Strategies {
   S1=0,    // Fimathe Classic
};
enum TypeTrend {
   UP=0,      // Trend Up
   DOWN=1,    // Trend Down
};
enum TypeStop {
   S_AUTO=0,    // Stop OutBox (Automatic)
   S_MANUAL=1,  // Stop Manual (Points)
   S_POS=2,     // Stop Position (Price)
};
enum TypeProfit {
   T_AUTO=0,    // Take 1 Nivel (Automatic) 
   T_2N=1,      // Take 2 Nivel (Automatic)
   T_MANUAL=2,  // Take Manual (Points)
   T_POS=3,     // Take Position (Price)
   T_JUS=4,     // Take Just (Automatic)   
};


// User initial parameters
input group                     "MACRO CHANNEL"
input double HighChannelPrice   = 1877.74;      // Price High Channel
input double LowChannelPrice    = 1761.37;      // Price Low Channel
input Fractionate CHFractionate = F3;           // Fractionate Macro Channel
input MarkChannel MChannel      = AC;           // Markations Channel
input TypeTrend TTrend          = UP;           // Trend Type

input group                      "TRADE SETTINGS"
input ENUM_TIMEFRAMES TF        = PERIOD_CURRENT;// Trade Time Frame
input Strategies STGS           = S1;           // Trade Strategy
input double Lote               = 0.01;         // Trade Lote 
input bool OptionZero           = true;         // Auto Safe Operation      
input double OptionZeroPoints   = 360.0;        // Safe Operation Points
input TypeProfit TP             = T_JUS;        // Take Profit
input TypeStop SL               = S_AUTO;       // Stop Loss
input double BigBarSizeLimit    = 500.0;        // Ignore Big Bar Size
input double GapSizeLimit       = 500.0;        // Ignore Open Market GAP Size
input int WaitCandlesAfterTrade = 1;            // Wait New Candles
input string TradeStart         = "01:06";      // Trade Start Time
input string TradeEnd           = "23:59";      // Trade End Time

input group                      "TRADE MANUAL SETTINGS"
input double TPManual           = 360.0;        // Manual Take Profit
input double SLManual           = 360.0;        // Manual Stop Loss
input double TPPostion          = 0.0;          // Price Take Profit
input double SLPostion          = 0.0;          // Price Stop Loss

// Global Variables
string OBJS_HLINE_ID            = "FTR";
double PRICE_HIGH_CH            = 0.00;
double PRICE_LOW_CH             = 0.00;
double SIZE_CH                  = 0.00;
double MACRO_CH_HIGH            = 0.00;
double MACRO_CH_LOW             = 0.00;
double ZERO_CH_HIGH             = 0.00;
double ZERO_CH_LOW              = 0.00;
bool ZERO_LOSS                  = false; 
int TICKET                      = 0;
double REF_CH_PRICE             = 0.0;
double ZN_CH_PRICE              = 0.0;
string EA_VERSION               = "FTR_v04";
string TREND                    = "";
double TAKE                     = 0.0;
double STOP                     = 0.0;
int WAIT_CANDLE_NUMBER          = 0;
bool SEARCH_NEW_CH              = false;
bool REQUOTE_TRADE              = false;
bool CHECK_GAP                  = true;
double REQUOTE_TAKE             = 0.0;
double REQUOTE_STOP             = 0.0;
string REQUOTE_TYPE             = 0.0;
double T_POS_PRICE              = 0.0;
double S_POS_PRICE              = 0.0;
double BLUE_HIGH_CH             = 0.0;
double BLUE_LOW_CH              = 0.0;
string LAST_TRADE_TYPE          = "";
bool VERIFY_CONTINUE_TRADE      = false;
double OPEN_POSITION_PRICE      = 0.0;

// Global Arrays
MqlRates ChannelRates[];
MqlRates MacroRates[];
MqlRates Rates[];
double ChannelPrices[2];
double HlineObjectsArray[];



//+------------------------------------------------------------------+
//| Custom functions initializations                                 |
//+------------------------------------------------------------------+
void HlineCreate(string Name, string Value, color Color, ENUM_LINE_STYLE Style, int Width, string Timeframes, string Description){
   
   hline.Create(0, Name, 0, Value);
   hline.Color(Color);
   hline.Style(Style);
   hline.Width(Width);
   hline.Timeframes(Timeframes);
   hline.Description(Description);
   
}
double NormalizePrice(double price){

   double ts=SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return(NormalizeDouble(price / ts, 0) * ts);
}
  
double sizeChannelInPoints(double h_price, double l_price){

   double channel_length = h_price - l_price;
   return NormalizePrice(channel_length);
}

double FindMidChannel(double high_line, double low_line) {

   return NormalizePrice(((high_line + low_line) / 2));
}

double expandChannels(double SIZE_CHannel) {

   //--- Get initial rates
   CopyRates(_Symbol, PERIOD_CURRENT, 0, 5, MacroRates);
   ArraySetAsSeries(MacroRates, true);

   //--- Set local variables
   double channel_plus=0.0;
   double line_num=1;
   double expand=0.0;

   //--- Expand channel for top
   if(MacroRates[1].close > HighChannelPrice){
      expand = HighChannelPrice;

      while(MacroRates[1].close > expand)
        {
         channel_plus = expand + SIZE_CHannel;
         HlineCreate("ExpandedCh_" + IntegerToString(line_num), channel_plus, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
         expand = channel_plus;
         line_num++;
        };

   } else if(MacroRates[1].close < LowChannelPrice){
         //--- Expand channel for bottom
         expand = LowChannelPrice;

         while(MacroRates[1].close > expand){
            channel_plus = expand - SIZE_CHannel;
            HlineCreate("ExpandedCh_" + IntegerToString(line_num), channel_plus, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
            expand = channel_plus;
            line_num++;
         };

   } else {
      expand = HighChannelPrice;
   }
   
   return expand;
}
  
void MacroMarkations() {
   
   HlineCreate("HighLine", HighChannelPrice, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
   HlineCreate("LowLine", LowChannelPrice, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
   
   double size_main_channel = sizeChannelInPoints(HighChannelPrice, LowChannelPrice);
   double last_high_line = expandChannels(size_main_channel);
   double last_low_line = last_high_line - size_main_channel;
   double channel_50 = FindMidChannel(last_high_line, last_low_line);
   double channel_25_l = FindMidChannel(channel_50, last_low_line);
   double channel_25_h = FindMidChannel(channel_50, last_high_line);
      
   if(CHFractionate == F1) {
      HlineCreate("Fractionate_50%", channel_50, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      
   } else if(CHFractionate == F2) {
   
      HlineCreate("Fractionate_25%_T", channel_25_h, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_25%_M", channel_50, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_25%_B", channel_25_l, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      
   } else if(CHFractionate == F3) {
   
      HlineCreate("Fractionate_25%_T", channel_25_h, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_25%_M", channel_50, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_25%_B", channel_25_l, clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_12,5%_1", FindMidChannel(last_high_line, channel_25_h), clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_12,5%_2", FindMidChannel(channel_25_h, channel_50), clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_12,5%_3", FindMidChannel(channel_50, channel_25_l), clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
      HlineCreate("Fractionate_12,5%_4", FindMidChannel(channel_25_l, last_low_line), clrBlack, STYLE_SOLID, 2, OBJ_ALL_PERIODS, OBJS_HLINE_ID);
   }
   
}
bool PRICE_IN_BLUE = false;
void FindPriceChannel(string obj_desc, ENUM_TIMEFRAMES period=PERIOD_CURRENT, bool only_black=false, bool only_blue=false) {
   
   ArrayFree(HlineObjectsArray);
   ArrayFree(Rates);
   
   CopyRates(_Symbol, period, 0, 5, Rates);
   ArraySetAsSeries(Rates, true);
   
   int array_len=1;
      
   for(int i=0; i <= ObjectsTotal(0, 0); i++) {
      
      if (ObjectGetString(0, ObjectName(0, i), OBJPROP_TEXT) == obj_desc) {
         if(only_black){
            string obj_name = ObjectName(0, i);
            int lineStyle = ObjectGetInteger(0, obj_name, OBJPROP_STYLE);
            if(lineStyle == 0){
               ArrayResize(HlineObjectsArray, ArraySize(HlineObjectsArray) + 1);
               HlineObjectsArray[array_len-1] = ObjectGetDouble(0, ObjectName(0, i), OBJPROP_PRICE);
               array_len++;
            }
         }else if(only_blue){
            string obj_name = ObjectName(0, i);
            int Color = ObjectGetInteger(0, obj_name, OBJPROP_COLOR);
            if(Color == 16711680){
               ArrayResize(HlineObjectsArray, ArraySize(HlineObjectsArray) + 1);
               HlineObjectsArray[array_len-1] = ObjectGetDouble(0, ObjectName(0, i), OBJPROP_PRICE);
               array_len++;
            }
         }else{;
            ArrayResize(HlineObjectsArray, ArraySize(HlineObjectsArray) + 1);
            HlineObjectsArray[array_len-1] = ObjectGetDouble(0, ObjectName(0, i), OBJPROP_PRICE);
            array_len++;
         }
      }
   
   }
   
   ArraySort(HlineObjectsArray);
   
   if(only_blue){
      

      if (Rates[1].close >= HlineObjectsArray[0] && Rates[1].close <= HlineObjectsArray[1] ) {
         // Prince in low channel
         BLUE_HIGH_CH = HlineObjectsArray[1];
         BLUE_LOW_CH  = HlineObjectsArray[0];
         PRICE_IN_BLUE = true;
         
      }else if (Rates[1].close >= HlineObjectsArray[2] && Rates[1].close <= HlineObjectsArray[3] ) {
         // Prince in high channel
         BLUE_HIGH_CH = HlineObjectsArray[3];
         BLUE_LOW_CH  = HlineObjectsArray[2];
         
         PRICE_IN_BLUE = true;
      }else {
         // Out
         PRICE_IN_BLUE = false;
      }
      
   }else {
   
      // Find Low Channel
      for(int i=0; i < ArraySize(HlineObjectsArray); i++) {
         if (Rates[1].close > HlineObjectsArray[i] ) {
            ChannelPrices[0] = HlineObjectsArray[i];
         }
      }
      // Find High Channel
      for(int i=ArraySize(HlineObjectsArray)-1; i > 0; i--) {
         if (Rates[1].close < HlineObjectsArray[i] ) {
            ChannelPrices[1] = HlineObjectsArray[i];
         }
      }
      PRICE_HIGH_CH = ChannelPrices[1];
      PRICE_LOW_CH  = ChannelPrices[0];
   }
}

void MarkationsM15(double high_channel, double low_channel) {
   
   MACRO_CH_HIGH = high_channel;
   MACRO_CH_LOW = low_channel;
   
   double mid_channel_m15 = FindMidChannel(high_channel, low_channel);
   double splited_mid_m15 = FindMidChannel(high_channel, mid_channel_m15);
   double zones_size = sizeChannelInPoints(splited_mid_m15, mid_channel_m15) / 2;
   double continue_zone_top = NormalizePrice(high_channel + zones_size);
   double pullback_zone_top = NormalizePrice(high_channel - zones_size);
   double continue_zone_mid = NormalizePrice(mid_channel_m15 + zones_size);
   double pullback_zone_mid = NormalizePrice(mid_channel_m15 - zones_size);
   double continue_zone_bottom = NormalizePrice(low_channel + zones_size);
   double pullback_zone_bottom = NormalizePrice(low_channel - zones_size);
   double top_neutro = FindMidChannel(pullback_zone_top, continue_zone_mid);
   double btm_neutro = FindMidChannel(pullback_zone_mid, continue_zone_bottom);
      
   HlineCreate("TOP_ZC", continue_zone_top, clrBlue, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   HlineCreate("TOP_ZP", pullback_zone_top, clrBlue, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   //HlineCreate("TOP_N", top_neutro, clrGray, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   //HlineCreate("MID_ZC", continue_zone_mid, clrMagenta, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   //HlineCreate("M15_MID", mid_channel_m15, clrBlack, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   //HlineCreate("MID_ZP", pullback_zone_mid, clrMagenta, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   //HlineCreate("BTM_N", btm_neutro, clrGray, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   HlineCreate("BTM_ZP", continue_zone_bottom, clrBlue, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
   HlineCreate("BTM_ZC", pullback_zone_bottom, clrBlue, STYLE_DASHDOT, 1, OBJ_PERIOD_M15|OBJ_PERIOD_M1, OBJS_HLINE_ID);
 
}

void RefreshChannels(){
   
   
   if(Rates[1].close > MACRO_CH_HIGH || Rates[1].close < MACRO_CH_LOW) {
      
      double ch_size = sizeChannelInPoints(MACRO_CH_HIGH, MACRO_CH_LOW);
      ObjectsDeleteAll(0, 0, OBJ_HLINE);
      MacroMarkations();
      
      PRICE_LOW_CH = MACRO_CH_HIGH;
      PRICE_HIGH_CH = PRICE_LOW_CH + ch_size;
      
      if(MChannel == AC){
         FindPriceChannel(OBJS_HLINE_ID);
         MarkationsM15(PRICE_HIGH_CH, PRICE_LOW_CH);
      }
   }
   
   if(Rates[1].close < MACRO_CH_LOW) {
      
      double ch_size = sizeChannelInPoints(MACRO_CH_HIGH, MACRO_CH_LOW);
      ObjectsDeleteAll(0, 0, OBJ_HLINE);
      MacroMarkations();
           
      PRICE_HIGH_CH = MACRO_CH_LOW;
      PRICE_LOW_CH = PRICE_HIGH_CH - ch_size;
      
      if(MChannel == AC){
         FindPriceChannel(OBJS_HLINE_ID);
         MarkationsM15(PRICE_HIGH_CH, PRICE_LOW_CH);
      }
   }
}

bool IsNewCandle() {
    static datetime last_candle_time = 0;
    datetime current_candle_time = iTime(_Symbol, TF, 0);
    
    if(current_candle_time != last_candle_time) {
        last_candle_time = current_candle_time;
        return true;
    }
    return false;
}



void MoveStopToZeroZero(){
   
   double operation_safe = OptionZeroPoints * _Point;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
      
      if(Rates[1].close > (ZERO_CH_HIGH + operation_safe)) {
         
         //double open_price =  PositionGetDouble(POSITION_PRICE_OPEN);
         double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point;
         double new_stoploss = OPEN_POSITION_PRICE + spread;
         bool result = trade.PositionModify(TICKET, new_stoploss, PositionGetDouble(POSITION_TP));
         
         if(result) {
            Print("Modify position successful!");
            ZERO_LOSS = false;
            OPEN_POSITION_PRICE = 0.0;
         } else {
            Print("Error in modify position: ", trade.ResultRetcode());
         }

      }
      
   }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
   
      if(Rates[1].close < (ZERO_CH_LOW - operation_safe)) {
         
         double spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) * _Point;
         double new_stoploss = OPEN_POSITION_PRICE - spread;
         bool result = trade.PositionModify(TICKET, new_stoploss, PositionGetDouble(POSITION_TP));
         
         if(result) {
            Print("Modify position successful!");
            ZERO_LOSS = false;
            OPEN_POSITION_PRICE = 0.0;
         } else {
            Print("Error in modify position: ", trade.ResultRetcode());
         }
      }
         
   }
     
}

double TakeProfit(string order_type, double channel_price){
   
   double tp=0.0;
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits); 
   
   if(order_type == "buy"){
   
      if(TP == T_AUTO){
         tp = NormalizeDouble(channel_price + (SIZE_CH * 2), _Digits);
      } else if (TP == T_2N){
         tp = NormalizeDouble(channel_price + (SIZE_CH * 4), _Digits);
      } else if (TP == T_MANUAL){
         tp = NormalizeDouble(ask + (TPManual * _Point), _Digits);
      }  else if(TP == T_POS){
         tp = NormalizeDouble(T_POS_PRICE, _Digits);
      } else if(TP == T_JUS){
         FindPriceChannel(OBJS_HLINE_ID, PERIOD_CURRENT, true);
         tp = NormalizeDouble(PRICE_HIGH_CH, _Digits);
      }
      
   } else {
      if(TP == T_AUTO){
         tp = NormalizeDouble(channel_price - (SIZE_CH * 2), _Digits);
      } else if (TP == T_2N){
         tp = NormalizeDouble(channel_price - (SIZE_CH * 4), _Digits);
      } else if (TP == T_MANUAL){
         tp = NormalizeDouble(ask - (TPManual * _Point), _Digits);
      } else if(TP == T_POS){
         tp = NormalizeDouble(T_POS_PRICE, _Digits);
      } else if(TP == T_JUS){
         FindPriceChannel(OBJS_HLINE_ID, PERIOD_CURRENT, true);
         tp = NormalizeDouble(PRICE_LOW_CH, _Digits);
      }
   }

   
   return tp;
}

double StopLoss(string order_type, double channel_price){
   
   double sl=0.0;
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   
   if(order_type == "buy"){
 
      if(SL == S_AUTO){
         sl = NormalizeDouble(channel_price, _Digits);
      } else if (SL == S_MANUAL){
         sl = NormalizeDouble(bid - (SLManual * _Point), _Digits);
      } else if (SL == S_POS){
         sl = NormalizeDouble(S_POS_PRICE, _Digits);
      } 
      
   } else {
      if(SL == S_AUTO){
         sl = NormalizeDouble(channel_price, _Digits);
      } else if (SL == S_MANUAL){
         sl = NormalizeDouble(bid + (SLManual * _Point), _Digits);
      } else if (SL == S_POS){
         sl = NormalizeDouble(S_POS_PRICE, _Digits);
      } 
   
   }
   return sl;
}

bool IsBigBar(){
   double bar_size = (Rates[1].open - Rates[1].close);
   double size = BigBarSizeLimit * _Point;
   
   if (bar_size > (BigBarSizeLimit * _Point)){
      SEARCH_NEW_CH = true;
      return true;
      
   }else {
      return false;
   }
}

void RequoteTradeOnTick(){

   bool result_trade = false;
   
   if (REQUOTE_TRADE){

      
      if(REQUOTE_TYPE == "buy"){
         double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);       
         result_trade = trade.Buy(Lote, NULL, ask, REQUOTE_STOP, REQUOTE_TAKE, EA_VERSION);
 
      }else {
         double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);        
         result_trade = trade.Sell(Lote, NULL, bid, REQUOTE_STOP, REQUOTE_TAKE, EA_VERSION);
      }
   }

   if(result_trade){
      REQUOTE_TRADE = false;
   }
   
}
bool IsMarketOpen() {
    datetime market_open = StringToTime(TradeStart);
    datetime market_close = StringToTime(TradeEnd);
    datetime current_candle_time = iTime(_Symbol, TF, 0);
    
    //Print("MKT Open: ", market_open, " - MKT Close: ", market_close, " - Current Time: ", current_candle_time);
    
    //datetime current_time = TimeLocal();
    if(current_candle_time >= market_open && current_candle_time <= market_close) {
        //Print("MKT Open!");
        return true;
    }
    Print("MKT Close!");
    return false;

}
void SearchNewChannels(){

   CopyRates(_Symbol, TF, 0, 5, Rates);
   RefreshChannels();
   FindPriceChannel(OBJS_HLINE_ID);
   
   if(TREND == "UP"){
      REF_CH_PRICE = PRICE_HIGH_CH;
      ZN_CH_PRICE = REF_CH_PRICE - (SIZE_CH * 2) ;
   
   }else {
      REF_CH_PRICE = PRICE_LOW_CH;
      ZN_CH_PRICE = REF_CH_PRICE + (SIZE_CH * 2);
   }
   
   SEARCH_NEW_CH = false;
}


bool IsGap(){
   
   if(CHECK_GAP){
   
      double open_price = iClose(_Symbol, TF, 0);
      double last_price = iClose(_Symbol, TF, 1);
      double gap_size = open_price - last_price;
      
      if(gap_size > (GapSizeLimit * _Point)){
         SEARCH_NEW_CH = true;
         CHECK_GAP = false;
         return true;
      }
      CHECK_GAP = false;
      return false;
   }

   return false;
}

bool CAN_TRADE = false;


void SendBuyPosition(){
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);         

   TAKE = TakeProfit("buy", BLUE_HIGH_CH);
   STOP = StopLoss("buy", BLUE_LOW_CH);  
   bool result_trade = trade.Buy(Lote, NULL, ask, STOP, TAKE, EA_VERSION);
   TICKET = PositionGetTicket(0); 
   CAN_TRADE = false;
   LAST_TRADE_TYPE = "buy";
   ZERO_CH_HIGH = BLUE_HIGH_CH;
   ZERO_LOSS = true;
   OPEN_POSITION_PRICE = ask;

}

void SendSellPosition(){
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);        
   
   TAKE = TakeProfit("sell", BLUE_LOW_CH);
   STOP = StopLoss("sell", BLUE_HIGH_CH);
   bool result_trade = trade.Sell(Lote, NULL, bid, STOP, TAKE, EA_VERSION);
   CAN_TRADE = false;
   LAST_TRADE_TYPE = "sell";
   ZERO_LOSS = true;
   ZERO_CH_LOW = BLUE_LOW_CH;
   OPEN_POSITION_PRICE = bid;
   TICKET = PositionGetTicket(0);
}

void StategyOne(){
   
   if(VERIFY_CONTINUE_TRADE){
      CopyRates(_Symbol, TF, 0, 5, Rates);

      if(Rates[1].close < BLUE_LOW_CH){
         SendSellPosition();
         
      } else if(Rates[1].close > BLUE_HIGH_CH){
         SendBuyPosition();
      }

      VERIFY_CONTINUE_TRADE = false;
   }
   
   if(!CAN_TRADE){
      RefreshChannels();
      FindPriceChannel(OBJS_HLINE_ID, PERIOD_CURRENT, false, true);

   }

   Comment("BLUE_UP: ", BLUE_HIGH_CH, " - BLUE_DW: ", BLUE_LOW_CH);
   
   CopyRates(_Symbol, TF, 0, 5, Rates);
   
   if(PositionsTotal() == 0 && PRICE_IN_BLUE){
      CAN_TRADE = true;
   }
   
   if (PositionsTotal() == 0 && !IsBigBar() && WAIT_CANDLE_NUMBER == 0 && CAN_TRADE){
      
      if(Rates[1].close > BLUE_HIGH_CH){
         SendBuyPosition();
         
      }else if(Rates[1].close < BLUE_LOW_CH){
         SendSellPosition();
      
      }

            
   }else if(ZERO_LOSS == true && OptionZero == true){
      MoveStopToZeroZero();
      
   } else if(WAIT_CANDLE_NUMBER > 0 ){
      WAIT_CANDLE_NUMBER--;
      
   }
   

   
}   


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   ObjectsDeleteAll(0, 0, OBJ_HLINE);
       
   MacroMarkations();
   
   if(MChannel == AC){
      FindPriceChannel(OBJS_HLINE_ID);
      MarkationsM15(ChannelPrices[1], ChannelPrices[0]);
   }
   
   FindPriceChannel(OBJS_HLINE_ID);
   SIZE_CH = sizeChannelInPoints(ChannelPrices[1], ChannelPrices[0]);
   
   if(TTrend == UP){
      TREND = "UP";
      REF_CH_PRICE = PRICE_HIGH_CH;
      ZN_CH_PRICE = REF_CH_PRICE - (SIZE_CH * 2) ;
      
   }else {
      TREND = "DOWN";
      REF_CH_PRICE = PRICE_LOW_CH;
      ZN_CH_PRICE = REF_CH_PRICE + (SIZE_CH * 2);
   }
   
   FindPriceChannel(OBJS_HLINE_ID);
   RefreshChannels();
   T_POS_PRICE = TPPostion;
   S_POS_PRICE = SLPostion;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){

   //ObjectsDeleteAll(0, 0, OBJ_HLINE);
   
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   
   RequoteTradeOnTick();
   
   if(IsNewCandle()) {

      if(SEARCH_NEW_CH){
         SearchNewChannels();
      }
      
      if (STGS == S1 && !IsGap()){
         StategyOne();
      }
   }
   
}
//+------------------------------------------------------------------+
void OnTradeTransaction( const MqlTradeTransaction &Trans, const MqlTradeRequest&, const MqlTradeResult& ){

   if (HistoryDealSelect(Trans.deal) && (HistoryDealGetInteger(Trans.deal, DEAL_REASON) == DEAL_REASON_TP)){
        
     VERIFY_CONTINUE_TRADE = true;
     WAIT_CANDLE_NUMBER = WaitCandlesAfterTrade;
     ZERO_LOSS = false;
        
   } else if( HistoryDealSelect(Trans.deal) && (HistoryDealGetInteger(Trans.deal, DEAL_REASON) == DEAL_REASON_SL)){
      
      VERIFY_CONTINUE_TRADE = true;
      WAIT_CANDLE_NUMBER = WaitCandlesAfterTrade;
      ZERO_LOSS = false;
   }
   
   

}
//+------------------------------------------------------------------+
//|                                                         baby.mq4 |
//|                                                  Olivier Ghafari |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Olivier Ghafari"
#property link      ""
#property version   "1.00"
#property strict

#define MAGICMA  22021992
#define BEAR "bear"
#define BULL "bull"

//--- input parameters
input double Lots = 0.3;
input bool Stop_Loss = true;
input bool Dynamic_SL = true;
input int TrailingStop=300; 

static input string growth; //--- Lot growing during time ---
input bool Growthing_Lot = false;
input double LotsGrowth = 1.02;

static input string lean; //--- Scalping SL during time ---
input double Leaner = 5;

//not recommended
static input string correct; //--- Not recomanded ---
input bool Correction = false;

static input string supertrend; //--- SuperTrend ---
//---- input parameters de QuivoFx
input int Periods=10;
input double Multiplier=4.0;
input int Correction_Mode=0;
input int PointSize=1;
input int MaxBars=1000;
input bool ShowBreakout=true;
input bool ShowCorrection=true;
input bool ShowPullback=true;
input bool SendAlert=false;
input bool SendEmail=false;
input bool SendPush=false;
input bool OnTrendChange=true;
input bool OnBreakout=true;
input bool OnCorrection=true;
input bool OnPullback=true;
static input string Bands; //--- Bollinger Bands ---
input int InpBandsPeriod=20;
input int InpBandsShift=0;
input double InpBandsDeviations=2.0;

double upSignal = EMPTY_VALUE;
double downSignal = EMPTY_VALUE;
double upTrend = EMPTY_VALUE;
double downTrend = EMPTY_VALUE;
double correction = EMPTY_VALUE;
string market = "null";
double bandsSMA0 =0;
double bandsSMA1 = 1;
double LotsApplied = Lots;

//upTrend = iCustom(NULL, 0, "Supertrend Plus Free",Periods,Multiplier,Correction_Mode,PointSize,MaxBars,ShowBreakout,ShowCorrection,ShowPullback,SendAlert,SendEmail,SendPush,OnTrendChange,OnBreakout,OnCorrection,OnPullback, 0,1);
//downTrend = iCustom(NULL, 0, "Supertrend Plus Free",Periods,Multiplier,Correction_Mode,PointSize,MaxBars,ShowBreakout,ShowCorrection,ShowPullback,SendAlert,SendEmail,SendPush,OnTrendChange,OnBreakout,OnCorrection,OnPullback, 1,1);
  
  
//+------------------------------------------------------------------+
//| Calculate open positions                                         |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol){
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA)
        {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
}

void OpenPosition(bool Pos){
   //close old position
   if(CalculateCurrentOrders(Symbol())!=0){
      //close old pos
      for(int i=0;i<OrdersTotal();i++){
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
         if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) break;
         //--- check order type 
         if(OrderType()==OP_BUY){
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,0,White)){
               Print("OrderClose error ",GetLastError());
            }
            break;
         }else if(OrderType()==OP_SELL){
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,0,White)){
               Print("OrderClose error ",GetLastError());
            }
            break;
         }
      }
   }
   
   //open New
   if (Pos){
      if (Stop_Loss)
         OrderSend(Symbol(),OP_BUY,LotsApplied,Ask,0,Ask-Point*TrailingStop,0,"",MAGICMA,0,Blue);
      else
         OrderSend(Symbol(),OP_BUY,LotsApplied,Ask,0,0,0,"",MAGICMA,0,Blue);
      if (Growthing_Lot){
         LotsApplied = LotsApplied*LotsGrowth;
      }
   }else{
      if (Stop_Loss)
         OrderSend(Symbol(),OP_SELL,LotsApplied,Bid,0,Bid+Point*TrailingStop,0,"",MAGICMA,0,Red);
      else
         OrderSend(Symbol(),OP_SELL,LotsApplied,Bid,0,0,0,"",MAGICMA,0,Red);
      if (Growthing_Lot){
         LotsApplied = LotsApplied*LotsGrowth;
      }
   }
}
  
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick(){
      if(Volume[0]>1) return;
//--- check for history and trading
   if(Bars<5 || IsTradeAllowed()==false)
      return;
   
   if (Dynamic_SL){RefreshSL();}
   
   downSignal = iCustom(NULL, 0, "Supertrend Plus",Periods,Multiplier,Correction_Mode,PointSize,MaxBars,ShowBreakout,ShowCorrection,ShowPullback,SendAlert,SendEmail,SendPush,OnTrendChange,OnBreakout,OnCorrection,OnPullback, 6,1);
   upSignal = iCustom(NULL, 0, "Supertrend Plus",Periods,Multiplier,Correction_Mode,PointSize,MaxBars,ShowBreakout,ShowCorrection,ShowPullback,SendAlert,SendEmail,SendPush,OnTrendChange,OnBreakout,OnCorrection,OnPullback, 5,1);
   //bandsSMA0 = iCustom(NULL, 0, "Bands",InpBandsPeriod,InpBandsShift,InpBandsDeviations, 0,1);
   //bandsSMA1 = iCustom(NULL, 0, "Bands",InpBandsPeriod,InpBandsShift,InpBandsDeviations, 0,2);
   
   if (downSignal!=EMPTY_VALUE){
         market = BEAR;
         OpenPosition(false);
   }else if (upSignal!=EMPTY_VALUE){
         market = BULL;
         OpenPosition(true);
   }
   if (Correction && market!="null"){CorrectionFunc();}
}

//Dynamic Stop loss
void RefreshSL(){
   bool res;
//--- modifies Stop Loss price for buy order 
   if(TrailingStop>0) { 
      if (OrderSelect(0,SELECT_BY_POS)==true){ 

         if (OrderType()==OP_BUY){
            if(OrderStopLoss()<Ask-Point*TrailingStop)  { 
                  res=OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(Ask-Point*TrailingStop,Digits),OrderTakeProfit(),0,Blue); 
                  if(!res) {Print("Error in OrderModify. Error code=",GetLastError()); }
                  else {Print("Order modified successfully."); }
            } else{
               res=OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(OrderStopLoss()+(Point*Leaner),Digits),OrderTakeProfit(),0,Blue); 
               if(!res) {Print("Error in OrderModify. Error code=",GetLastError()); }
               else{Print("Order modified successfully."); }
            }
         }else {
            if(OrderStopLoss()>Bid+Point*TrailingStop)  { 
                  res=OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(Bid+Point*TrailingStop,Digits),OrderTakeProfit(),0,Blue); 
                  if(!res){Print("Error in OrderModify. Error code=",GetLastError()); }
                  else{Print("Order modified successfully."); }
             } else{
                res=OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(OrderStopLoss()-(Point*Leaner),Digits),OrderTakeProfit(),0,Blue); 
                if(!res) {Print("Error in OrderModify. Error code=",GetLastError()); }
                else {Print("Order modified successfully.");}
             }
         }
     }
   }
}

void CorrectionFunc(){
   correction = iCustom(NULL, 0, "Supertrend Plus",Periods,Multiplier,Correction_Mode,PointSize,MaxBars,ShowBreakout,ShowCorrection,ShowPullback,SendAlert,SendEmail,SendPush,OnTrendChange,OnBreakout,OnCorrection,OnPullback, 2,1);
   if (correction!= EMPTY_VALUE){
      if (market==BULL){
         //Si aucun ordre en cours
         if(CalculateCurrentOrders(Symbol())==0){
            OpenPosition(true);
         }
      }else if (market==BEAR){
         if(CalculateCurrentOrders(Symbol())==0){
            OpenPosition(false);
         }
      }
   }
}